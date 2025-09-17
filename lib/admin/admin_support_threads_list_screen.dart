// lib/admin/admin_support_threads_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/support_thread_model.dart';
import '../models/profile_model.dart';
import 'admin_support_thread_detail_screen.dart';

class AdminSupportThreadsListScreen extends StatefulWidget {
  const AdminSupportThreadsListScreen({super.key});

  @override
  State<AdminSupportThreadsListScreen> createState() =>
      _AdminSupportThreadsListScreenState();
}

class _AdminSupportThreadsListScreenState
    extends State<AdminSupportThreadsListScreen> {
  final _supabase = Supabase.instance.client;

  List<SupportThread> _threads = [];
  bool _isLoading = true;
  String _error = '';
  // RealtimeChannel? _threadsChannel; // Removed for now

  String _currentFilterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, Profile?> _userProfileCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchThreads(); // Changed name
  }

  void _onSearchChanged() {
    if (mounted) {
      _searchQuery = _searchController.text.trim();
      _fetchThreads(); // Re-fetch
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // _threadsChannel?.unsubscribe().catchError((e) {
    //   print('Error unsubscribing threads channel: $e');
    // }); // Removed for now
    super.dispose();
  }

  Future<Profile?> _fetchAndCacheUserProfile(String userId) async {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId];
    }
    try {
      // For postgrest 2.4.2, directly awaiting the builder that results
      // from .single() is common.
      final responseData = await _supabase
          .from('profiles')
          .select('id, username, phone, role, created_at, email')
          .eq('id', userId)
          .single(); // This returns a Future<Map<String, dynamic>>

      // No .execute() needed here as .single() is already a Future
      // if (responseData.error != null) { // .single() throws error, doesn't return PostgrestResponse
      //   print("Error fetching profile for $userId: ${responseData.error!.message}");
      //   _userProfileCache[userId] = null;
      //   return null;
      // }
      final profile = Profile.fromMap(responseData); // responseData is already the Map
      _userProfileCache[userId] = profile;
      return profile;
    } catch (e) {
      print("Exception fetching profile for $userId: $e");
      if (e is PostgrestException && e.code == 'PGRST116') { // PGRST116: JSON object requested, multiple (or no) rows returned
        print("Profile not found or multiple profiles for $userId");
      }
      _userProfileCache[userId] = null;
      return null;
    }
  }

  Future<void> _fetchThreads() async { // Renamed from _fetchThreadsAndListenForChanges
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      PostgrestQueryBuilder queryBuilder = _supabase.from('support_threads');

      // The select statement including the foreign table
      const String selectStatement = '*, user_profile:user_id(username, id)';

      // Apply filters if any.
      // After first filter (.eq or .or), it becomes PostgrestFilterBuilder
      dynamic currentQuery = queryBuilder;

      if (_currentFilterStatus != 'all') {
        currentQuery = currentQuery.eq('status', _currentFilterStatus);
      }

      if (_searchQuery.isNotEmpty) {
        final isSearchUuid = _isValidUuid(_searchQuery);
        String orConditions =
            'subject.ilike.%$_searchQuery%,last_message_preview.ilike.%$_searchQuery%';
        if (isSearchUuid) {
          orConditions += ',user_id.eq.$_searchQuery';
        }
        currentQuery = currentQuery.or(orConditions);
      }

      // Now apply select and order.
      // .select() can be called on PostgrestQueryBuilder or PostgrestFilterBuilder
      // .order() is on PostgrestTransformBuilder (result of .select())
      final transformBuilder = currentQuery
          .select(selectStatement)
          .order('updated_at', ascending: false);

      // For postgrest 2.4.2, directly await the PostgrestTransformBuilder
      // or the Future it returns. It does not have .execute().
      final responseData = await transformBuilder; // This should yield List<Map<String, dynamic>>

      if (!mounted) return;

      // `responseData` is directly the List<Map<String, dynamic>> or similar.
      // There's no separate `.error` or `.data` property on `responseData` itself.
      // Errors would have been thrown as exceptions.

      final List<dynamic> dataList = responseData as List<dynamic>; // Ensure it's a list

      if (dataList.isNotEmpty) {
        final fetchedThreads = dataList
            .map((map) => SupportThread.fromMap(map as Map<String, dynamic>))
            .toList();

        for (var thread in fetchedThreads) {
          await _fetchAndCacheUserProfile(thread.userId);
        }

        if (mounted) {
          setState(() {
            _threads = fetchedThreads;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _threads = [];
          });
        }
      }
    } on PostgrestException catch (pgError) { // Catch Postgrest specific errors
      print('Supabase query error fetching threads: ${pgError.message}');
      if (mounted) {
        setState(() {
          _error = 'Failed to load threads: ${pgError.message} (Code: ${pgError.code})';
        });
      }
    } catch (e, s) { // Catch other generic errors
      print('Generic exception fetching threads: $e\n$s');
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // Realtime listener setup removed for now
  }

  bool _isValidUuid(String uuid) {
    final uuidRegExp = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegExp.hasMatch(uuid);
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && mounted) {
      _userProfileCache.clear();
      setState(() {
        _currentFilterStatus = newFilter;
      });
      _fetchThreads();
    }
  }

  Future<void> _forceRefresh() async {
    _userProfileCache.clear();
    await _fetchThreads();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> statusFilters = [
      'all', 'open', 'pending_admin_reply', 'pending_user_reply',
      'resolved_by_user', 'resolved_by_admin', 'closed_by_user', 'closed_by_admin'
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Support Threads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _forceRefresh,
            tooltip: "Refresh List",
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_alt),
            onSelected: _onFilterChanged,
            tooltip: "Filter by Status",
            itemBuilder: (BuildContext context) {
              return statusFilters.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((e) => e[0].toUpperCase() + e.substring(1))
                      .join(' ')),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Subject, Preview, User ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: $_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 16)),
                ))
                : _threads.isEmpty
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      'No support threads found for filter: "$_currentFilterStatus" and search: "$_searchQuery".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium),
                ))
                : RefreshIndicator(
              onRefresh: _forceRefresh,
              child: ListView.separated(
                itemCount: _threads.length,
                separatorBuilder: (context, index) => const Divider(
                    height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final thread = _threads[index];
                  final bool isAdminUnread = !thread.isReadByAdmin &&
                      (thread.status == 'pending_admin_reply' ||
                          thread.status == 'open');

                  final cachedProfile = _userProfileCache[thread.userId];
                  String userDisplay = 'User: ${thread.userId.substring(0, 8)}...';
                  if (cachedProfile != null && cachedProfile.username.isNotEmpty) {
                    userDisplay = 'User: ${cachedProfile.username} (${thread.userId.substring(0, 4)}...)';
                  }
                  // Removed direct access to thread.userProfile as it's not in your model

                  return ListTile(
                    tileColor: isAdminUnread ? theme.colorScheme.primary.withOpacity(0.08) : null,
                    leading: CircleAvatar(
                      backgroundColor: isAdminUnread ? theme.colorScheme.primary : theme.colorScheme.secondary,
                      foregroundColor: isAdminUnread ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondary,
                      child: Text(
                        thread.status.isNotEmpty ? thread.status.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      thread.subject ?? 'Thread ID: ${thread.id.substring(0, 8)}',
                      style: TextStyle(fontWeight: isAdminUnread ? FontWeight.bold : FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          'Status: ${thread.status.replaceAll("_", " ")}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (thread.lastMessagePreview != null && thread.lastMessagePreview!.isNotEmpty)
                          Text(
                            'Preview: ${thread.lastMessagePreview}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontStyle: FontStyle.italic, color: theme.hintColor),
                          ),
                        Text(
                          'Last Update: ${DateFormat.yMd().add_jm().format(thread.updatedAt.toLocal())}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    trailing: isAdminUnread
                        ? Badge(
                      backgroundColor: theme.colorScheme.error,
                      label: const Text('New', style: TextStyle(fontSize: 9, color: Colors.white)),
                      child: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
                    )
                        : Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                    isThreeLine: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    onTap: () {
                      if (isAdminUnread) {
                        _supabase.from('support_threads')
                            .update({'is_read_by_admin': true})
                            .eq('id', thread.id)
                        // Directly await the update operation for postgrest 2.4.2
                            .then((data) { // .then() is used if it's a Future<void> or Future<List> etc.
                          // Check for errors if 'data' is a PostgrestResponse-like object or handle exceptions
                          print("Admin: Marked thread ${thread.id} as read");
                          if (mounted) {
                            final indexToUpdate = _threads.indexWhere((t) => t.id == thread.id);
                            if (indexToUpdate != -1) {
                              setState(() {
                                _threads[indexToUpdate].isReadByAdmin = true;
                              });
                            }
                          }
                        }).catchError((error){
                          print("Admin: Error marking thread as read: $error");
                          // Handle error, e.g., show a snackbar
                          if (error is PostgrestException) {
                            print("Error details: ${error.message}");
                          }
                        });
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminSupportThreadDetailScreen(thread: thread)),
                      ).then((_) {
                        _forceRefresh();
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

