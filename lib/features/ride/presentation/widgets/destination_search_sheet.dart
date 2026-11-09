import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/geo_point.dart';
import '../../domain/places_repository.dart';
import '../providers/route_providers.dart';

/// Opens destination search and returns the chosen suggestion, or `null` if
/// the host closes it.
///
/// [initialQuery] pre-fills the field (e.g. a recent destination); [near]
/// ranks results around the host.
Future<PlaceSuggestion?> showDestinationSearchSheet({
  required BuildContext context,
  String initialQuery = '',
  GeoPoint? near,
}) {
  return showModalBottomSheet<PlaceSuggestion>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _DestinationSearchSheet(
      initialQuery: initialQuery,
      near: near,
    ),
  );
}

class _DestinationSearchSheet extends ConsumerStatefulWidget {
  const _DestinationSearchSheet({required this.initialQuery, this.near});

  final String initialQuery;
  final GeoPoint? near;

  @override
  ConsumerState<_DestinationSearchSheet> createState() =>
      _DestinationSearchSheetState();
}

class _DestinationSearchSheetState
    extends ConsumerState<_DestinationSearchSheet> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  String? _error;
  bool _isSearching = false;
  bool _startNewSession = true;

  /// Each search gets an id so a slow, outdated response never overwrites a
  /// newer one.
  int _searchId = 0;

  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const int _minQueryLength = 2;
  static const double _heightFraction = 0.85;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(text));
  }

  Future<void> _search(String text) async {
    final query = text.trim();
    final id = ++_searchId;
    if (query.length < _minQueryLength) {
      setState(() {
        _results = const [];
        _error = null;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final result = await ref.read(placesRepositoryProvider).search(
          query,
          near: widget.near,
          newSession: _startNewSession,
        );
    _startNewSession = false;
    if (!mounted || id != _searchId) return;
    setState(() {
      _isSearching = false;
      switch (result) {
        case Success(:final value):
          _results = value;
          _error = value.isEmpty ? 'No places found.' : null;
        case Failed(:final failure):
          _results = const [];
          _error = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * _heightFraction;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _search,
                decoration: const InputDecoration(
                  hintText: 'Search destination',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (_isSearching)
              const LinearProgressIndicator(
                minHeight: 1,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.route),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(_error!, style: theme.textTheme.bodyMedium),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: AppSpacing.xl,
                  endIndent: AppSpacing.xl,
                  color: AppColors.divider,
                ),
                itemBuilder: (context, index) {
                  final place = _results[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xs,
                    ),
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(
                      place.primaryText,
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: place.secondaryText.isEmpty
                        ? null
                        : Text(
                            place.secondaryText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                    onTap: () => Navigator.of(context).pop(place),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
