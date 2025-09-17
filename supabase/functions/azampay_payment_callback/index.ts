// supabase/functions/azampay_payment_callback/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { corsHeaders } from "../_shared/cors.ts";

console.log("azampay_payment_callback function initializing (CLI deployment)...");

// --- Supabase Details (FOR TESTING ONLY - REPLACE WITH ENV VARS FOR PRODUCTION) ---
const SUPABASE_URL = "https://ptkdfuxoiupkmprpafcp.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0a2RmdXhvaXVwa21wcnBhZmNwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Nzc2MTk3NywiZXhwIjoyMDczMzM3OTc3fQ.NUagRWwAARjAP11UOFDhbqZnvHb3hfGW4SIBnint7JA";

serve(async (req: Request) => {
  console.log(`azampay_payment_callback: Received request - Method: ${req.method}`);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    console.warn(`azampay_payment_callback: Received non-POST method: ${req.method}`);
    return new Response(JSON.stringify({ error: "Method Not Allowed. Only POST is accepted." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json", "Allow": "POST" },
      status: 405,
    });
  }

  try {
    let callbackBody;
    try {
      callbackBody = await req.json();
    } catch (e) {
      const rawBody = await req.text(); // Get raw body if JSON parsing fails
      console.error("azampay_payment_callback: Invalid JSON in callback body.", e.message, "Raw Body (first 500 chars):", rawBody.substring(0,500));
      return new Response(JSON.stringify({ error: "Invalid JSON request body in callback." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400, // Bad Request
      });
    }

    console.log("azampay_payment_callback: Callback Body Received:", JSON.stringify(callbackBody, null, 2));

    // Extract fields based on AzamPay Callback Documentation
    const utilityRef = callbackBody.utilityref; // Your externalId sent during checkout
    const azamTransactionRef = callbackBody.reference; // AzamPay's transaction ID
    const paymentStatusFromAzam = String(callbackBody.transactionstatus || "unknown").toLowerCase(); // 'success' or 'failure'
    const messageFromAzam = callbackBody.message || "No message provided by AzamPay.";
    const msisdnFromAzam = callbackBody.msisdn;
    const amountFromAzam = callbackBody.amount;

    let lookupId = null;
    let lookupField = null;

    // Prioritize lookup by utilityref (your externalId) as it's directly from your system
    if (utilityRef && typeof utilityRef === 'string') {
      lookupId = utilityRef;
      lookupField = 'external_transaction_id'; // This should match what you stored as your 'externalId'
    } else if (azamTransactionRef && typeof azamTransactionRef === 'string') {
      // Fallback to AzamPay's transaction ID if utilityref is missing
      lookupId = azamTransactionRef;
      lookupField = 'transaction_reference'; // This should match what you stored from AzamPay's checkout response
    }

    if (!lookupId || !lookupField) {
      console.error("azampay_payment_callback: Missing usable transaction identifier (utilityref or reference) in callback.", callbackBody);
      return new Response(JSON.stringify({ error: "Callback data incomplete: Missing transaction identifier." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400, // Acknowledge with Bad Request if critical info is missing
      });
    }
    console.log(`azampay_payment_callback: Lookup using ${lookupField} = ${lookupId}. AzamPay Status: ${paymentStatusFromAzam}`);

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: purchase, error: findError } = await supabaseAdmin
      .from('purchases')
      .select('*')
      .eq(lookupField, lookupId)
      .maybeSingle();

    if (findError) {
      console.error(`azampay_payment_callback: Database error finding purchase with ${lookupField}='${lookupId}':`, findError.message);
      // Still return 200 to AzamPay, but log internal error
      return new Response(JSON.stringify({ error: "Internal database error during purchase lookup." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200, // Acknowledge callback to prevent retries
      });
    }

    if (!purchase) {
      console.warn(`azampay_payment_callback: No purchase found for ${lookupField}: ${lookupId}. This might be an old or unmatched callback.`);
      return new Response(JSON.stringify({ message: "Purchase record not found, callback acknowledged but not processed further." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200, // Acknowledge to AzamPay
      });
    }
    console.log(`azampay_payment_callback: Found purchase record ID: ${purchase.id}, Current Status: ${purchase.status}`);

    // Idempotency check: if already completed or failed, don't reprocess
    if (purchase.status === 'completed' || purchase.status === 'failed') {
      console.log(`azampay_payment_callback: Purchase ${purchase.id} already finalized with status '${purchase.status}'. Ignoring redundant callback.`);
      return new Response(JSON.stringify({ message: "Transaction already finalized." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    let newStatus = purchase.status; // Default to current status
    if (paymentStatusFromAzam === 'success') {
      newStatus = 'completed';
    } else if (paymentStatusFromAzam === 'failure' || paymentStatusFromAzam === 'failed') { // cater for 'failed' too
      newStatus = 'failed';
    } else {
      console.warn(`azampay_payment_callback: Unrecognized AzamPay transactionstatus '${paymentStatusFromAzam}'. Current purchase status: ${purchase.status}. Keeping as is.`);
    }
    console.log(`azampay_payment_callback: Derived new status: ${newStatus} from AzamPay status: ${paymentStatusFromAzam}`);

    if (newStatus !== purchase.status) {
      const { error: updateError } = await supabaseAdmin
        .from('purchases')
        .update({
          status: newStatus,
          gateway_callback_response: callbackBody, // Store the full callback
          gateway_message: messageFromAzam, // Store the message from AzamPay
          // Optionally update phone or amount if they can change or if you want to verify
          // phone: msisdnFromAzam || purchase.phone,
          // amount_paid: parseFloat(amountFromAzam) || purchase.amount_paid,
        })
        .eq('id', purchase.id);

      if (updateError) {
        console.error(`azampay_payment_callback: Database error updating purchase ${purchase.id} to status ${newStatus}:`, updateError.message);
        // Return 200 to AzamPay, but log internal error
        return new Response(JSON.stringify({ error: "Internal database error during purchase update." }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200, // Acknowledge callback
        });
      }
      console.log(`azampay_payment_callback: Purchase ${purchase.id} status successfully updated to ${newStatus}.`);
    } else {
      console.log(`azampay_payment_callback: No status change required for purchase ${purchase.id}. Current/New: ${purchase.status}`);
    }

    return new Response(JSON.stringify({ message: "Callback processed successfully." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200, // Always send 200 OK to AzamPay if callback is acknowledged
    });

  } catch (err) {
    console.error("azampay_payment_callback: Unhandled error in callback handler:", err.message, err.stack);
    return new Response(JSON.stringify({ error: "Internal server error processing callback.", details: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200, // Critical to send 200 to AzamPay to prevent retries, even if internal processing had an issue.
    });
  }
});
