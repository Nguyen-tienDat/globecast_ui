import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../screens/create_meeting/create_meeting_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/join_meeting/join_meeting_screen.dart';
import '../screens/meeting/meeting_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class GcbAppRouter extends RootStackRouter {
  GcbAppRouter({super.navigatorKey});

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: HomeRoute.page,
      initial: true,
      path: '/',
    ),
    AutoRoute(
      page: JoinMeetingRoute.page,
      path: '/join',
    ),
    AutoRoute(
      page: CreateMeetingRoute.page,
      path: '/create',
    ),
    AutoRoute(
      page: MeetingRoute.page,
      path: '/meeting/:code',
    ),
  ];
}