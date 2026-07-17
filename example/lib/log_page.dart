import 'dart:async';
import 'dart:io';

import 'package:background_task_example/model/lat_lng.dart';
import 'package:background_task_example/model/sembast_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'log_page'),
        builder: (_) => const LogPage(),
      ),
    );
  }

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<LatLng> items = [];
  bool isLoading = false;

  final ScrollController scrollController = ScrollController();
  final int defaultLimit = 20;

  @override
  void initState() {
    onRefresh();
    super.initState();
  }

  Future<void> onRefresh() async {
    final data = await SembastRepository.find(
      limit: items.length > defaultLimit ? items.length : defaultLimit,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      items = data;
    });
  }

  Future<void> onLoadMore() async {
    final data = await SembastRepository.find(
      offset: items.length,
      limit: defaultLimit,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      items = [...items, ...data];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Log'),
        actions: [
          IconButton(
            onPressed: () async {
              await HapticFeedback.heavyImpact();
              await SembastRepository.clear();
              if (mounted) {
                setState(() {
                  items = [];
                });
              }
            },
            icon: const Icon(Icons.delete),
            iconSize: 32,
          ),
        ],
      ),
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (items.length >= defaultLimit &&
              notification.metrics.extentAfter == 0) {
            Future(() async {
              if (isLoading) {
                return;
              }
              setState(() {
                isLoading = true;
              });
              try {
                await Future<void>.delayed(const Duration(milliseconds: 1000));
                await onLoadMore();
              } on Exception catch (e) {
                debugPrint(e.toString());
              } finally {
                setState(() {
                  isLoading = false;
                });
              }
            });
          }
          return true;
        },
        child: Scrollbar(
          controller: scrollController,
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  await onRefresh();
                  await Future<void>.delayed(const Duration(milliseconds: 500));
                },
              ),
              SliverMainAxisGroup(
                slivers: [
                  SliverList.separated(
                    itemBuilder: (context, index) {
                      final data = items[index];
                      return ListTile(
                        title: Text(
                          '${data.lat}, ${data.lng}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        leading: Text(
                          data.id.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          DateFormat(
                            'yyyy.M.d H:mm:ss',
                            'ja_JP',
                          ).format(data.createdAt),
                        ),
                        onTap: () async {
                          final coordinates = '${data.lat},${data.lng}';
                          final uri = Platform.isIOS
                              ? Uri.https('maps.apple.com', '/', {
                                  'll': coordinates,
                                  'q': coordinates,
                                })
                              : Uri(
                                  scheme: 'geo',
                                  path: coordinates,
                                  queryParameters: {'q': coordinates},
                                );
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!launched && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('地図アプリを開けませんでした。')),
                            );
                          }
                        },
                      );
                    },
                    separatorBuilder: (context, index) {
                      return const Divider(height: 1);
                    },
                    itemCount: items.length,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 16, bottom: 56),
                    sliver: SliverToBoxAdapter(
                      child: Visibility(
                        visible: isLoading,
                        child: const CupertinoActivityIndicator(),
                      ),
                    ),
                  ),
                ],
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ).copyWith(bottom: 108),
                      child: const Text('nothing', textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
