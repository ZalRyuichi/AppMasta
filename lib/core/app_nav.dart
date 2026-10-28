import 'package:flutter/material.dart';

/// Navigator key global — dipakai supaya Bocchi (companion AI) bisa
/// membuka layar/fitur dari mana saja tanpa butuh BuildContext lokal.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
