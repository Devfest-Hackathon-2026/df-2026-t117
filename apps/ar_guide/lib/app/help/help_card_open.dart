// How many help cards (help_card.dart) are open now. The card is shown by raising the phone towards a
// Japanese person, which on S04 would otherwise count as "device raised -> AR" (F36) and switch the screen
// under the card. DeviceRaiseEffects (logic/device_raise.dart) stops listening while this is above 0.
import 'package:flutter/foundation.dart';

/// Incremented in the card's initState and decremented in its dispose.
final ValueNotifier<int> helpCardsOpen = ValueNotifier<int>(0);
