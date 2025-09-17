// supabase/functions/pay_via_azampay/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { corsHeaders } from "../_shared/cors.ts";

console.log("pay_via_azampay function initializing (CLI deployment, updated credentials)...");

// --- Supabase Details (FOR TESTING ONLY - REPLACE WITH ENV VARS FOR PRODUCTION) ---
const SUPABASE_URL = "https://ptkdfuxoiupkmprpafcp.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0a2RmdXhvaXVwa21wcnBhZmNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3NjE5NzcsImV4cCI6MjA3MzMzNzk3N30.2zyzlkJ538we3jQO5av-iySOaqw-QFamKz7fGQhLmJw";
const SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0a2RmdXhvaXVwa21wcnBhZmNwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Nzc2MTk3NywiZXhwIjoyMDczMzM3OTc3fQ.NUagRWwAARjAP11UOFDhbqZnvHb3hfGW4SIBnint7JA";

// --- AzamPay Credentials (FROM YOUR LATEST UPDATE - FOR TESTING ONLY) ---
const AZAMPAY_APP_NAME = "betcrack";
const AZAMPAY_CLIENT_ID = "a39e6b05-b81e-4d85-872b-217683a82985";
const AZAMPAY_CLIENT_SECRET = "YJK70MUEg5LhfcCvjE2+CBpgIOCnRNfK3fe1vWOsz7ccKlbguXz2oiL+GMky2yegCsNwd1KB1IPEbTC0XVg9AYEhdFiopGDHiLKdrfJNtLnYZKcqMXSgvF0tmQISHrWIA8bgZYtWS/BRjX0P4NbZPotV1U/tFbwuLe3YtxQgpmFGDEa99O44056GjBHfJTVTFb8CkC5WkllqbT+q8foITCmoA+Hwb7NWx7+typxY/GWAsILkdliKClB53+2FzzUF5hv2pMAIgwK84vyJ5bZA+vmMhtjcowbXTk2kdHx02D6haxDoMTY6XrMH/bIqC0j/fsx7ztzfeBGIrjSgN+55Gsfdkqt7EsLRnrGvhCNSDn7o1mRLXrJendlMrHvsWD4Rq4uzhBBe1S9Jr53iohpYF4GmLDZTzEmSKy9+ScftCo5Mzud8uxUhHHkn3XNcFBJBM8Ybi3q9ZrXUL9sWYBNPCrcLUS5q5SzxbQMZyp0cUz3j1654vJsu7Uv0KpRYQ+Dj3jPiQio+qB19cXkZPsXreP02HCe9pUHjpOUXAsmb3ESGD67PFAFoEmt7xsY47W/Vo3qQ+RQe4BBRn0x/xwsE0cM/djwcUrz3dnwY/JT1b1z61q/sxe9aU7/nNuEfiVQ19rosBqWOqcUf+an7cWJRoCzUImSvrMMU0dwHZlOam1s=";

// Token URL from AzamPay documentation image
const AZAMPAY_TOKEN_URL = "https://authenticator-sandbox.azampay.co.tz/api/v1/auth/token";

// MNO Checkout URL from AzamPay documentation image
const AZAMPAY_MNO_CHECKOUT_URL = "https://sandbox.azampay.co.tz/azampay/checkout";

serve(async (req: Request) => {
  console.log(`pay_via_azampay: Incoming request - ${req.method} ${req.url}`);

  if (req.method === "OPTIONS") {
    console.log("pay_via_azampay: OPTIONS request - sending CORS headers");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.error("pay_via_azampay: Missing or invalid Authorization header");
      return new Response(
        JSON.stringify({ error: "Missing or invalid Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      console.error("pay_via_azampay: User authentication failed", userError?.message || "User not found");
      return new Response(
        JSON.stringify({ error: "User not authenticated or token invalid." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const userId = user.id;
    console.log(`pay_via_azampay: Authenticated user: ${userId}`);

    let body: { phone: string; provider: string; betslip_id: string; amount: number };
    try {
      body = await req.json();
    } catch (e) {
      console.error("pay_via_azampay: Failed to parse JSON body", e.message);
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { phone, provider, betslip_id, amount } = body;

    if (!phone || !provider || !betslip_id || amount == null || typeof amount !== 'number' || amount <= 0) {
      console.error("pay_via_azampay: Missing or invalid parameters in request body.", body);
      return new Response(
        JSON.stringify({
          error: "Missing or invalid fields: phone, provider, betslip_id, and a positive amount are required.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log(`pay_via_azampay: Request params - phone: ${phone}, provider: ${provider}, betslip_id: ${betslip_id}, amount: ${amount}`);
// --- AzamPay Access Token Request (using appName, clientId, clientSecret in body) ---
    console.log(`pay_via_azampay: Requesting AzamPay token from ${AZAMPAY_TOKEN_URL}...`);
    const tokenPayload = {
      appName: AZAMPAY_APP_NAME,
      clientId: AZAMPAY_CLIENT_ID,
      clientSecret: AZAMPAY_CLIENT_SECRET,
    };

    let azamTokenResponse;
    try {
      azamTokenResponse = await fetch(AZAMPAY_TOKEN_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(tokenPayload),
      });
    } catch (e) {
      console.error("pay_via_azampay: Network error fetching AzamPay token:", e.message, e.stack);
      return new Response(
        JSON.stringify({ error: "Network error: Failed to reach AzamPay token endpoint.", details: e.message }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tokenResponseText = await azamTokenResponse.text();
    let tokenData;

    if (!azamTokenResponse.ok) {
      console.error(`pay_via_azampay: AzamPay token request failed: ${azamTokenResponse.status} - ${tokenResponseText}`);
      try { tokenData = JSON.parse(tokenResponseText); } catch { /* ignore parsing error */ }
      return new Response(
        JSON.stringify({
          error: "Failed to obtain AzamPay access token.",
          details: tokenData || tokenResponseText,
          statusCode: azamTokenResponse.status
        }),
        { status: azamTokenResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      tokenData = JSON.parse(tokenResponseText);
    } catch (e) {
      console.error("pay_via_azampay: Failed to parse AzamPay token response JSON:", tokenResponseText, e.message);
      return new Response(
        JSON.stringify({ error: "Invalid JSON response from AzamPay token endpoint.", details: tokenResponseText }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const accessToken = tokenData?.data?.accessToken; // As per AzamPay token response structure
    if (!accessToken) {
      console.error("pay_via_azampay: Access token missing in AzamPay response structure.", tokenData);
      return new Response(
        JSON.stringify({ error: "AzamPay access token not found in expected response structure.", details: tokenData }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log("pay_via_azampay: AzamPay token acquired.");
const externalId = `${betslip_id}_${crypto.randomUUID().slice(0, 12)}`;

    // --- MNO Checkout Payload (as per AzamPay MNO Checkout documentation) ---
    const checkoutPayload = {
      accountNumber: String(phone),
      amount: Number(amount), // MNO Checkout expects amount as a number
      currency: "TZS",
      externalId: externalId,
      provider: provider,
    };

    console.log(`pay_via_azampay: Initiating MNO payment with AzamPay to ${AZAMPAY_MNO_CHECKOUT_URL}... Payload:`, JSON.stringify(checkoutPayload, null, 2));

    let paymentResponse;
    try {
      paymentResponse = await fetch(AZAMPAY_MNO_CHECKOUT_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(checkoutPayload),
      });
    } catch (e) {
      console.error("pay_via_azampay: Network error sending MNO payment request:", e.message, e.stack);
      return new Response(
        JSON.stringify({ error: "Network error: Failed to reach AzamPay MNO payment endpoint.", details: e.message }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const paymentResultText = await paymentResponse.text();
    let paymentResultJson;

    if (!paymentResponse.ok) {
      console.error(`pay_via_azampay: MNO Payment request failed: ${paymentResponse.status} - ${paymentResultText}`);
      try { paymentResultJson = JSON.parse(paymentResultText); } catch { /* ignore */ }
      return new Response(
        JSON.stringify({
          error: "MNO Payment initiation failed with AzamPay.",
          details: paymentResultJson || paymentResultText,
          statusCode: paymentResponse.status
        }),
        { status: paymentResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      paymentResultJson = JSON.parse(paymentResultText);
    } catch (e) {
      console.error("pay_via_azampay: Failed to parse AzamPay MNO payment success response JSON:", paymentResultText, e.message);
      return new Response(
        JSON.stringify({ error: "Invalid JSON response from AzamPay MNO payment endpoint after OK status.", details: paymentResultText }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("pay_via_azampay: MNO Payment initiation successful with AzamPay.", paymentResultJson);

// --- Save to purchases table (Supabase Admin Client) ---
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    console.log(`pay_via_azampay: Inserting purchase record for user ${userId}, betslip ${betslip_id}`);
    const { data: purchaseData, error: insertError } = await supabaseAdmin
      .from("purchases")
      .insert({
        user_id: userId,
        betslip_id: betslip_id,
        phone: String(phone),
        payment_method: provider,
        amount_paid: Number(amount),
        status: "pending",
        transaction_reference: paymentResultJson.transactionId || externalId,
        external_transaction_id: externalId,
        gateway_response: paymentResultJson,
      })
      .select()
      .single();

    if (insertError) {
      console.error("pay_via_azampay: Failed to insert purchase record:", insertError);
      return new Response(
        JSON.stringify({
          error: "MNO Payment initiated with AzamPay, but failed to save purchase record locally.",
          details: insertError.message,
          azampay_response: paymentResultJson
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log("pay_via_azampay: Purchase record inserted successfully:", purchaseData);

    return new Response(JSON.stringify({
      message: paymentResultJson.message || "MNO Payment initiated successfully with AzamPay.",
      success: paymentResultJson.success ?? true,
      azampay_transaction_id: paymentResultJson.transactionId,
      purchase_record: purchaseData,
    }), {
      status: 200, // Or paymentResponse.status if AzamPay returns 202 etc. on success
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("pay_via_azampay: Unhandled error in function:", err.message, err.stack);
    return new Response(
      JSON.stringify({ error: "An unexpected server error occurred.", details: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});


