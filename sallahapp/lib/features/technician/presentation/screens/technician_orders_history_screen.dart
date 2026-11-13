import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../client/presentation/bloc/language_cubit.dart';
/// Full order history for the technician — all jobs they ever worked on.
class TechnicianOrdersHistoryScreen extends StatefulWidget {
  const TechnicianOrdersHistoryScreen({super.key});

  @override
  State<TechnicianOrdersHistoryScreen> createState() =>
      _TechnicianOrdersHistoryScreenState();
}

class _TechnicianOrdersHistoryScreenState
    extends State<TechnicianOrdersHistoryScreen> {
  String _filter = 'all';

  bool _matches(String status) {
    switch (_filter) {
      case 'active':
        return [
          'accepted',
          'en_route',
          'in_progress',
        ].contains(status);

      case 'completed':
        return status == 'completed';

      case 'cancelled':
        return status == 'cancelled';

      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    final t = context.watch<LanguageCubit>().state.t;
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          t('technician_orders_history.title'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _Chip(
                  label: t(
                    'technician_orders_history.filters.all',
                  ),
                  value: 'all',
                  current: _filter,
                  onTap: (v) {
                    setState(() => _filter = v);
                  },
                ),
                _Chip(
                  label: t(
                    'technician_orders_history.filters.active',
                  ),
                  value: 'active',
                  current: _filter,
                  onTap: (v) {
                    setState(() => _filter = v);
                  },
                ),
                _Chip(
                  label: t(
                    'technician_orders_history.filters.completed',
                  ),
                  value: 'completed',
                  current: _filter,
                  onTap: (v) {
                    setState(() => _filter = v);
                  },
                ),
                _Chip(
                  label: t(
                    'technician_orders_history.filters.cancelled',
                  ),
                  value: 'cancelled',
                  current: _filter,
                  onTap: (v) {
                    setState(() => _filter = v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: fs.streamCompletedJobsForTechnician(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '${t('technician_orders_history.error')}: '
                      '${snapshot.error}',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final jobs = snapshot.data!
                    .where(
                      (j) => _matches(
                        j['status'] as String? ?? '',
                      ),
                    )
                    .toList();

                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.work_history_rounded,
                          size: 44,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t(
                            'technician_orders_history.empty.title',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _filter == 'all'
                              ? t(
                                  'technician_orders_history.empty.all',
                                )
                              : t(
                                  'technician_orders_history.empty.filtered',
                                ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24,
                  ),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (_, i) {
                    return _JobHistoryCard(
                      job: jobs[i],
                      fs: fs,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final sel = current == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.primary
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: sel
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _JobHistoryCard extends StatelessWidget {
  const _JobHistoryCard({
    required this.job,
    required this.fs,
  });

  final Map<String, dynamic> job;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;

    final label = job['serviceLabel'] as String? ??
        t('technician_orders_history.service');

    final clientName = job['clientName'] as String? ??
        t('technician_orders_history.client');

    final status = job['status'] as String? ?? '';

    final price =
        (job['priceQuoteMAD'] as num?)?.toDouble() ?? 0;

    final commission =
        (job['commissionMAD'] as num?)?.toDouble() ?? 0;

    final earned = price - commission;

    final createdAt = job['createdAt'];

    final date = createdAt is Timestamp
        ? DateFormat('dd/MM/yyyy').format(
            createdAt.toDate(),
          )
        : '';

    final clientRating =
        (job['clientRatingByTech'] as num?)?.toInt();

    final techRating =
        (job['clientRating'] as num?)?.toInt();

    final (bg, fg, statusLabel) = switch (status) {
      'completed' => (
          AppColors.successLight,
          AppColors.success,
          t(
            'technician_orders_history.status.completed',
          ),
        ),
      'cancelled' => (
          AppColors.dangerLight,
          AppColors.dangerDark,
          t(
            'technician_orders_history.status.cancelled',
          ),
        ),
      'in_progress' => (
          AppColors.primaryLight,
          AppColors.primaryDark,
          t(
            'technician_orders_history.status.in_progress',
          ),
        ),
      'en_route' => (
          const Color(0xFFE8EDFB),
          const Color(0xFF2B4EAE),
          t(
            'technician_orders_history.status.en_route',
          ),
        ),
      _ => (
          AppColors.background,
          AppColors.textSecondary,
          status,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),

              const SizedBox(width: 4),

              Text(
                clientName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              if (date.isNotEmpty)
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),

          if (status == 'completed') ...[
            const SizedBox(height: 10),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        '${earned.toStringAsFixed(0)} MAD',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                if (techRating != null)
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < techRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: i < techRating
                            ? AppColors.gold
                            : AppColors.border,
                      ),
                    ),
                  )
                else
                  Text(
                    t(
                      'technician_orders_history.not_rated',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),

                const Spacer(),

                if (clientRating == null)
                  _RateClientButton(
                    job: job,
                    fs: fs,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RateClientButton extends StatelessWidget {
  const _RateClientButton({
    required this.job,
    required this.fs,
  });

  final Map<String, dynamic> job;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;

    return TextButton.icon(
      onPressed: () => _showRateSheet(context),

      icon: const Icon(
        Icons.star_outline_rounded,
        size: 15,
      ),

      label: Text(
        t(
          'technician_orders_history.rate_button',
        ),
        style: const TextStyle(
          fontSize: 12,
        ),
      ),

      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        minimumSize: Size.zero,
        tapTargetSize:
            MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _showRateSheet(
    BuildContext context,
  ) async {
    final t = context.read<LanguageCubit>().state.t;

    final clientId = job['clientId'] as String?;
    final requestId = job['requestId'] as String?;

    if (clientId == null || requestId == null) {
      return;
    }

    int stars = 5;

    final commentCtrl =
        TextEditingController();

    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 +
                  MediaQuery.of(ctx)
                      .viewInsets
                      .bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'technician_orders_history.rate_sheet.title',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  t(
                    'technician_orders_history.rate_sheet.description',
                  ).replaceFirst(
                    '{clientName}',
                    job['clientName'] ??
                        t(
                          'technician_orders_history.client',
                        ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children:
                        List.generate(5, (i) {
                      final filled =
                          i < stars;

                      return GestureDetector(
                        onTap: () {
                          setSheet(
                            () => stars = i + 1,
                          );
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 4,
                          ),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons
                                    .star_outline_rounded,
                            size: 40,
                            color: filled
                                ? AppColors.gold
                                : AppColors.border,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 6,
                    ),
                    child: Text(
                      [
                        '',
                        t(
                          'technician_orders_history.rating.very_bad',
                        ),
                        t(
                          'technician_orders_history.rating.bad',
                        ),
                        t(
                          'technician_orders_history.rating.okay',
                        ),
                        t(
                          'technician_orders_history.rating.good',
                        ),
                        t(
                          'technician_orders_history.rating.excellent',
                        ),
                      ][stars],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                        color: stars >= 4
                            ? AppColors.success
                            : stars >= 3
                                ? AppColors.gold
                                : AppColors.danger,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration:
                      InputDecoration(
                    hintText: t(
                      'technician_orders_history.rate_sheet.comment_hint',
                    ),
                    labelText: t(
                      'technician_orders_history.rate_sheet.comment_label',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheet(
                              () => submitting =
                                  true,
                            );

                            try {
                              await fs
                                  .rateTechnicianRatesClient(
                                requestId:
                                    requestId,
                                clientId:
                                    clientId,
                                stars: stars,
                                comment:
                                    commentCtrl
                                        .text
                                        .trim(),
                              );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);

                                ScaffoldMessenger
                                        .of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(
                                        'technician_orders_history.rate_sheet.success',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheet(
                                  () => submitting =
                                      false,
                                );

                                ScaffoldMessenger
                                        .of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e
                                          .toString()
                                          .replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },

                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            t(
                              'technician_orders_history.rate_sheet.submit',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    commentCtrl.dispose();
  }
}