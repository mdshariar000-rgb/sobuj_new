import 'package:flutter/material.dart';

/// Raw brand color values extracted from the Agro Hub Figma file
/// (file key `nzdCpnS4BL3o45z9kKUsRL`) via its REST API — a deep forest-green
/// canopy palette with a bright mint accent, on a near-white neutral surface.
abstract final class AppColors {
  /// Primary CTA green — buttons, active nav item, links.
  static const primary = Color(0xFF006D3F);

  /// Darkest forest green — splash background, curved hero headers.
  static const forestDark = Color(0xFF0B1A14);

  /// Mid-dark forest green — hero header panels over [forestDark].
  static const forestPanel = Color(0xFF183A2E);

  /// Bright mint accent — decorative rings, highlighted chips/badges.
  static const mint = Color(0xFF8DF8B5);

  /// App background.
  static const surface = Color(0xFFF7FAF7);

  /// Card/sheet surfaces above [surface].
  static const surfaceContainer = Color(0xFFFFFFFF);

  /// Muted badge/pill background on light surfaces.
  static const surfaceMuted = Color(0xFFF1F4F1);

  /// Primary body text on light surfaces.
  static const textDark = Color(0xFF1B1F1C);

  /// Secondary/muted text on light surfaces.
  static const textMuted = Color(0xFF717974);

  /// Secondary text on dark hero surfaces.
  static const textOnDarkMuted = Color(0xFF80A494);

  /// Card/input hairline border on light surfaces.
  static const border = Color(0xFFC1C8C3);

  /// Secondary label text (category eyebrows, meta rows) — slightly darker
  /// than [textMuted].
  static const label = Color(0xFF414845);

  /// Neutral grey button fill (e.g. "Joined"/"Invite" pills) — distinct from
  /// [surfaceMuted], a touch darker.
  static const buttonMuted = Color(0xFFECEFEC);

  /// A lighter mint variant used for filled buttons over [forestPanel]
  /// headers, with [mintButtonText] for its label/icon color.
  static const mintButton = Color(0xFF8AF5B3);
  static const mintButtonText = Color(0xFF007242);

  /// Pale mint fill — marketplace action tiles, category chips and the
  /// round chat buttons on listing cards.
  static const mintLight = Color(0xFFD3F8E2);

  static const error = Color(0xFFBA1A1A);
}
