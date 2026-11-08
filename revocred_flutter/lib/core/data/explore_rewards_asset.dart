import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/explore_rewards.dart';

const exploreRewardsAsset = 'assets/data/explore_rewards.json';

/// The copy shipped with the app. It matches the API's copy (checked in CI)
/// and is used offline and in mock mode.
Future<ExploreRewards> loadBundledExploreRewards([AssetBundle? bundle]) async {
  final text = await (bundle ?? rootBundle).loadString(exploreRewardsAsset);
  return ExploreRewards.fromJson(
    (jsonDecode(text) as Map).cast<String, dynamic>(),
  );
}
