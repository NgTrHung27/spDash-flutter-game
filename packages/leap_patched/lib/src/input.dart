import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'package:leap/leap.dart';
import 'package:leap/src/mixins/mixins.dart';

/// Combines touch screen and keyboard input into one API.
class SimpleCombinedInput extends Component
    with HasGameReference<LeapGame>, AppLifecycleAware {

  SimpleCombinedInput({
    SimpleKeyboardInput? keyboardInput,
  })  : _tapInput = SimpleTapInput(),
        _keyboardInput = keyboardInput ?? SimpleKeyboardInput();
  late final SimpleTapInput _tapInput;
  late final SimpleKeyboardInput _keyboardInput;
  double pressedTime = 0;
  bool justPressed = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(_tapInput);
    await add(_keyboardInput);
  }

  @override
  void appLifecycleStateChanged(
    AppLifecycleState previous,
    AppLifecycleState current,
  ) {
    // When the app is backgrounded or foregrounded, reset inputs to avoid
    // any weirdness with tap/key state getting out of sync.
    _tapInput.reset();
    _keyboardInput.keysDown.clear();
    pressedTime = 0;
    justPressed = false;
  }

  bool get _appFocused =>
      game.appState == AppLifecycleState.resumed ||
      game.appState == AppLifecycleState.detached;

  bool get isPressed =>
      _appFocused && (_tapInput.isPressed || _keyboardInput.isPressed);

  bool get isPressedLeft =>
      _appFocused && (_tapInput.isPressedLeft || _keyboardInput.isPressedLeft);

  bool get isPressedRight =>
      _appFocused &&
      (_tapInput.isPressedRight || _keyboardInput.isPressedRight);

  SimpleKeyboardInput get keyboardInput => _keyboardInput;
  SimpleTapInput get tapInput => _tapInput;

  @override
  void update(double dt) {
    if (isPressed) {
      justPressed = pressedTime == 0;
      pressedTime += dt;
    } else {
      pressedTime = 0;
    }
  }
}

class SimpleTapInput extends PositionComponent
    with TapCallbacks, HasGameReference<LeapGame> {
  SimpleTapInput({
    this.upEvent,
    this.downEvent,
  });

  TapUpEvent? upEvent;
  TapDownEvent? downEvent;

  @override
  bool get debugMode => true;

  bool get isPressed => downEvent != null && upEvent == null;

  bool get isPressedLeft {
    if (downEvent != null) {
      return isPressed &&
          downEvent!.devicePosition.x < game.canvasSize.x / 2;
    }
    return false;
  }

  bool get isPressedRight => isPressed && !isPressedLeft;

  @override
  Future<void> onLoad() async {
    size = (game.world as LeapWorld).map.size;
    return super.onLoad();
  }

  @override
  bool onTapUp(TapUpEvent event) {
    upEvent = event;
    return true;
  }

  @override
  bool onTapDown(TapDownEvent event) {
    downEvent = event;
    upEvent = null;
    return true;
  }

  @override
  bool onTapCancel(TapCancelEvent event) {
    reset();
    return true;
  }

  void reset() {
    downEvent = null;
    upEvent = null;
  }
}

class SimpleKeyboardInput extends Component with KeyboardHandler {
  SimpleKeyboardInput({
    Set<PhysicalKeyboardKey>? leftKeys,
    Set<PhysicalKeyboardKey>? rightKeys,
  }) {
    this.leftKeys = leftKeys ??
        {
          PhysicalKeyboardKey.arrowLeft,
          PhysicalKeyboardKey.keyA,
          PhysicalKeyboardKey.keyH,
        };

    this.rightKeys = rightKeys ??
        {
          PhysicalKeyboardKey.arrowRight,
          PhysicalKeyboardKey.keyD,
          PhysicalKeyboardKey.keyL,
        };

    relevantKeys = this.leftKeys.union(this.rightKeys);
  }

  late final Set<PhysicalKeyboardKey> leftKeys;

  late final Set<PhysicalKeyboardKey> rightKeys;

  late final Set<PhysicalKeyboardKey> relevantKeys;

  final Set<PhysicalKeyboardKey> keysDown = {};

  bool get isPressed => keysDown.isNotEmpty;

  bool get isPressedLeft =>
      isPressed && keysDown.intersection(leftKeys).isNotEmpty;

  bool get isPressedRight =>
      isPressed && keysDown.intersection(rightKeys).isNotEmpty;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Ignore irrelevant keys.
    if (relevantKeys.contains(event.physicalKey)) {
      if (event is KeyDownEvent) {
        keysDown.add(event.physicalKey);
      } else if (event is KeyUpEvent) {
        keysDown.remove(event.physicalKey);
      }
    }
    return true;
  }
}
