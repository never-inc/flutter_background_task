import 'dart:async';

import 'package:background_task_example/model/isar_repository.dart';
import 'package:background_task_example/model/lat_lng.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:map_launcher/map_launcher.dart';

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
    final data = await IsarRepository.isar.latLngs
        .where()
        .sortByCreatedAtDesc()
        .limit(items.length > defaultLimit ? items.length : defaultLimit)
        .findAll();
    setState(() {
      items = data;
    });
  }

  Future<void> onLoadMore() async {
    final data = await IsarRepository.isar.latLngs
        .where()
        .sortByCreatedAtDesc()
        .offset(items.length)
        .limit(defaultLimit)
        .findAll();
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
            onPressed: () {
              HapticFeedback.heavyImpact();
              IsarRepository.isar.writeTxnSync(() {
                IsarRepository.isar.latLngs.clearSync();
                setState(() {
                  items = [];
                });
              });
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
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        leading: Text(
                          data.id.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          DateFormat('yyyy.M.d H:mm:ss', 'ja_JP')
                              .format(data.createdAt),
                        ),
                        onTap: () async {
                          final availableMaps = await MapLauncher.installedMaps;
                          await availableMaps.first.showMarker(
                            coords: Coords(data.lat, data.lng),
                            title: '${data.lat}, ${data.lng}',
                          );
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
                      padding: const EdgeInsets.symmetric(horizontal: 16)
                          .copyWith(bottom: 108),
                      child: const Text(
                        'nothing',
                        textAlign: TextAlign.center,
                      ),
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
