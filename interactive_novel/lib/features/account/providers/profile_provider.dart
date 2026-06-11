import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_service.dart';

part 'profile_provider.g.dart';

@riverpod
ProfileService profileService(Ref ref) =>
    ProfileService(ref.watch(dioProvider));