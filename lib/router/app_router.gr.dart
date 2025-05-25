// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [CreateMeetingScreen]
class CreateMeetingRoute extends PageRouteInfo<void> {
  const CreateMeetingRoute({List<PageRouteInfo>? children})
    : super(CreateMeetingRoute.name, initialChildren: children);

  static const String name = 'CreateMeetingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CreateMeetingScreen();
    },
  );
}

/// generated route for
/// [HomeScreen]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomeScreen();
    },
  );
}

/// generated route for
/// [JoinMeetingScreen]
class JoinMeetingRoute extends PageRouteInfo<void> {
  const JoinMeetingRoute({List<PageRouteInfo>? children})
    : super(JoinMeetingRoute.name, initialChildren: children);

  static const String name = 'JoinMeetingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const JoinMeetingScreen();
    },
  );
}

/// generated route for
/// [MeetingScreen]
class MeetingRoute extends PageRouteInfo<MeetingRouteArgs> {
  MeetingRoute({Key? key, required String code, List<PageRouteInfo>? children})
    : super(
        MeetingRoute.name,
        args: MeetingRouteArgs(key: key, code: code),
        rawPathParams: {'code': code},
        initialChildren: children,
      );

  static const String name = 'MeetingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<MeetingRouteArgs>(
        orElse: () => MeetingRouteArgs(code: pathParams.getString('code')),
      );
      return MeetingScreen(key: args.key, code: args.code);
    },
  );
}

class MeetingRouteArgs {
  const MeetingRouteArgs({this.key, required this.code});

  final Key? key;

  final String code;

  @override
  String toString() {
    return 'MeetingRouteArgs{key: $key, code: $code}';
  }
}

/// generated route for
/// [SignInScreen]
class SignInRoute extends PageRouteInfo<void> {
  const SignInRoute({List<PageRouteInfo>? children})
    : super(SignInRoute.name, initialChildren: children);

  static const String name = 'SignInRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SignInScreen();
    },
  );
}

/// generated route for
/// [SignUpScreen]
class SignUpRoute extends PageRouteInfo<void> {
  const SignUpRoute({List<PageRouteInfo>? children})
    : super(SignUpRoute.name, initialChildren: children);

  static const String name = 'SignUpRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SignUpScreen();
    },
  );
}

/// generated route for
/// [WelcomeScreen]
class WelcomeRoute extends PageRouteInfo<void> {
  const WelcomeRoute({List<PageRouteInfo>? children})
    : super(WelcomeRoute.name, initialChildren: children);

  static const String name = 'WelcomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WelcomeScreen();
    },
  );
}
