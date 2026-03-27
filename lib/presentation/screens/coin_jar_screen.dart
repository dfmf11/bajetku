import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge2d/forge2d.dart' as b2;
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/providers.dart';
import '../../core/viewmodels/dashboard_viewmodel.dart';
import 'add_expense_screen.dart';

// ─────────────────────────────────────────────
// Pixels ↔ Box2D world conversion
// Box2D works best with objects 0.1–10 m wide.
// 50 px = 1 m  →  coin radius ≈ 0.48 m  ✓
// ─────────────────────────────────────────────
const double _ppm = 50.0; // pixels per meter

// ─────────────────────────────────────────────
// Coin entity (rendering + physics body ref)
// ─────────────────────────────────────────────
class _Coin {
  final b2.Body body;
  final String emoji;
  final double radiusPx;
  late final TextPainter _painter;

  // Pop animation state
  bool isPopping = false;
  double popProgress = 0.0; // 0 → 1 over the animation duration
  static const double popDuration = 0.3; // seconds

  _Coin({
    required this.body,
    required this.emoji,
    required this.radiusPx,
  }) {
    _painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: radiusPx * 2.0 * 0.88),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  double get x => body.position.x * _ppm;
  double get y => body.position.y * _ppm;

  void paint(Canvas canvas) {
    if (isPopping) {
      // Pop curve: scale up to 1.5x in the first 40%, then shrink to 0
      double scale;
      double opacity;
      if (popProgress < 0.4) {
        // Expand phase
        scale = 1.0 + (popProgress / 0.4) * 0.5; // 1.0 → 1.5
        opacity = 1.0;
      } else {
        // Shrink + fade phase
        final t = (popProgress - 0.4) / 0.6; // 0 → 1
        scale = 1.5 * (1.0 - t); // 1.5 → 0
        opacity = 1.0 - t; // 1 → 0
      }
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale, scale);
      final paint = Paint()..color = Color.fromRGBO(255, 255, 255, opacity);
      canvas.saveLayer(null, paint);
      _painter.paint(
        canvas,
        Offset(-_painter.width / 2, -_painter.height / 2),
      );
      canvas.restore(); // layer
      canvas.restore(); // transform
    } else {
      _painter.paint(
        canvas,
        Offset(x - _painter.width / 2, y - _painter.height / 2),
      );
    }
  }
}

// ─────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────
class _CoinPainter extends CustomPainter {
  final List<_Coin> coins;
  _CoinPainter(this.coins, {required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final coin in coins) {
      coin.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => true;
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class CoinJarScreen extends ConsumerStatefulWidget {
  const CoinJarScreen({super.key});

  @override
  ConsumerState<CoinJarScreen> createState() => _CoinJarScreenState();
}

class _CoinJarScreenState extends ConsumerState<CoinJarScreen>
    with SingleTickerProviderStateMixin {
  // ── Constants ──────────────────────────────
  final List<String> _emojis = ['🪙', '💎', '💰', '💵', '💎', '🪙'];
  static const int _maxCoins = 100;
  final Random _rand = Random();

  // ── Box2D world ────────────────────────────
  late b2.World _world;
  final List<_Coin> _coins = [];
  bool _physicsReady = false;
  Size _simSize = Size.zero;

  // ── Rendering ──────────────────────────────
  late final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // ── Spawning queue ─────────────────────────
  int _pendingSpawn = 0;
  int _spawnCooldown = 0;

  // ── Accelerometer ──────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // ── Coin size (set once we have screen size) ─
  double _coinRadiusPx = 24.0;

  // ── Drag interaction ───────────────────
  b2.Body? _groundBody; // static anchor for MouseJoint
  b2.MouseJoint? _dragJoint;
  _Coin? _draggedCoin;

  @override
  void initState() {
    super.initState();

    // Create the Box2D world with default downward gravity (10 m/s²)
    _world = b2.World(b2.Vector2(0, 10));

    _ticker = createTicker(_onTick)..start();

    // Accelerometer → update Box2D gravity directly
    _accelSub = accelerometerEventStream().listen((event) {
      // event.x: tilt right = negative → coins slide right
      // event.y: upright ≈ 9.8 → pull down (Y+ = down in our coords)
      _world.gravity = b2.Vector2(-event.x, event.y.clamp(0.1, 20.0));
    });

    // Queue initial coins from persisted income
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final income = ref.read(coinJarIncomeProvider);
      final spent = ref.read(dashboardViewModelProvider).totalSpent;
      final balance = (income - spent).clamp(0.0, income > 0 ? income : 0.0);
      _pendingSpawn =
          (income > 0) ? ((balance / income) * _maxCoins).round() : 0;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accelSub?.cancel();
    _frame.dispose();
    super.dispose();
  }

  // ─── Physics initialisation (once we know screen size) ───

  void _initPhysics() {
    final wM = _simSize.width / _ppm; // world width in meters
    final hM = _simSize.height / _ppm; // world height in meters

    _coinRadiusPx = _simSize.width / 16.0; // ~8 coins per row

    // Ground body (static, invisible) — needed as anchor for MouseJoint
    _createWall(b2.Vector2(0, hM), b2.Vector2(wM, hM));
    _createWall(b2.Vector2(0, -20), b2.Vector2(0, hM));
    _createWall(b2.Vector2(wM, -20), b2.Vector2(wM, hM));

    // Create a dedicated static ground body for drag joints
    _groundBody = _world.createBody(b2.BodyDef()..type = b2.BodyType.static);

    _physicsReady = true;
  }

  void _createWall(b2.Vector2 a, b2.Vector2 b) {
    final bodyDef = b2.BodyDef()..type = b2.BodyType.static;
    final body = _world.createBody(bodyDef);
    final shape = b2.EdgeShape()..set(a, b);
    final fixtureDef = b2.FixtureDef(shape)..friction = 0.5;
    body.createFixture(fixtureDef);
  }

  // ─── Game loop ────────────────────────────

  void _onTick(Duration elapsed) {
    // Wait for screen size from LayoutBuilder
    if (_simSize == Size.zero) return;

    // Init physics once
    if (!_physicsReady) _initPhysics();

    // Drain pending coins one per tick
    if (_pendingSpawn > 0) {
      _spawnCooldown--;
      if (_spawnCooldown <= 0) {
        _spawnOneCoin();
        _pendingSpawn--;
        _spawnCooldown = 1; // ~1 coin per frame ≈ 60 coins/sec
      }
    }

    // Step the Box2D world — this handles ALL collision, stacking, sleeping
    final rawDt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final dt = rawDt.clamp(0.001, 0.033); // cap at ~30fps step
    _world.stepDt(dt);

    // Advance pop animations and remove completed ones
    final toDestroy = <_Coin>[];
    for (final coin in _coins) {
      if (coin.isPopping) {
        coin.popProgress += dt / _Coin.popDuration;
        if (coin.popProgress >= 1.0) {
          toDestroy.add(coin);
        }
      }
    }
    for (final coin in toDestroy) {
      _coins.remove(coin);
      _world.destroyBody(coin.body);
    }

    _frame.value++; // trigger repaint
  }

  // ─── Coin management ──────────────────────

  void _spawnOneCoin() {
    final radiusM = _coinRadiusPx / _ppm;
    final xPx = _coinRadiusPx +
        _rand.nextDouble() * (_simSize.width - _coinRadiusPx * 2);
    final yPx = -_coinRadiusPx * 2 - _rand.nextDouble() * _coinRadiusPx;

    final bodyDef = b2.BodyDef()
      ..type = b2.BodyType.dynamic
      ..position = b2.Vector2(xPx / _ppm, yPx / _ppm)
      ..allowSleep = true; // Box2D built-in sleeping — no jitter once settled!

    final body = _world.createBody(bodyDef);

    final shape = b2.CircleShape()..radius = radiusM;
    final fixtureDef = b2.FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.4
      ..restitution = 0.2; // small bounce, then settle
    body.createFixture(fixtureDef);

    final emoji = _emojis[_rand.nextInt(_emojis.length)];
    _coins.add(_Coin(body: body, emoji: emoji, radiusPx: _coinRadiusPx));
  }

  void _spawnCoins(int count) {
    _pendingSpawn += count;
    _spawnCooldown = 0;
  }

  void resetAndDropAmount(int count) {
    // Remove all existing bodies from Box2D world
    for (final coin in _coins) {
      _world.destroyBody(coin.body);
    }
    _coins.clear();
    _pendingSpawn = 0;
    _spawnCooldown = 0;
    if (count > 0) _spawnCoins(count);
  }

  void spendDownTo(int target) async {
    if (target < 0) target = 0;
    int toRemove = _coins.where((c) => !c.isPopping).length - target;
    if (toRemove <= 0) return;

    // Sort non-popping coins by Y (highest = smallest Y = top of screen)
    final active = _coins.where((c) => !c.isPopping).toList()
      ..sort((a, b) => a.y.compareTo(b.y));

    for (int i = 0; i < toRemove && i < active.length; i++) {
      // Stagger the pop start so they don't all pop at the same instant
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (!mounted) return;
        active[i].isPopping = true;
        active[i].popProgress = 0.0;
        // Make the body a sensor so it stops colliding while popping
        for (final fixture in active[i].body.fixtures) {
          fixture.setSensor(true);
        }
      });
    }
  }

  // ─── Drag interaction ─────────────────────

  void _onDragStart(DragStartDetails details) {
    if (!_physicsReady) return;

    final touchX = details.localPosition.dx;
    final touchY = details.localPosition.dy;

    // Simple distance-based hit test — find closest coin under finger
    _draggedCoin = null;
    double bestDistSq = double.infinity;
    for (final coin in _coins) {
      if (coin.isPopping) continue;
      final dx = coin.x - touchX;
      final dy = coin.y - touchY;
      final distSq = dx * dx + dy * dy;
      if (distSq < coin.radiusPx * coin.radiusPx && distSq < bestDistSq) {
        bestDistSq = distSq;
        _draggedCoin = coin;
      }
    }

    if (_draggedCoin != null) {
      final worldPt = b2.Vector2(touchX / _ppm, touchY / _ppm);
      _draggedCoin!.body.setAwake(true);

      final jd = b2.MouseJointDef<b2.Body, b2.Body>()
        ..bodyA = _groundBody!
        ..bodyB = _draggedCoin!.body
        ..target.setFrom(worldPt)
        ..maxForce = 1000.0 * _draggedCoin!.body.mass
        ..dampingRatio = 0.7
        ..frequencyHz = 5.0;
      _dragJoint = b2.MouseJoint(jd);
      _world.createJoint(_dragJoint!);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragJoint == null) return;
    final b2.Vector2 screenPt =
        b2.Vector2(details.localPosition.dx, details.localPosition.dy);
    _dragJoint!.setTarget(screenPt / _ppm);
  }

  void _onDragEnd(DragEndDetails details) {
    _releaseDragJoint();
  }

  void _onDragCancel() {
    _releaseDragJoint();
  }

  void _releaseDragJoint() {
    if (_dragJoint != null) {
      _world.destroyJoint(_dragJoint!);
      _dragJoint = null;
      _draggedCoin = null;
    }
  }

  // ─── Dialogs ──────────────────────────────

  Future<void> _showUpdateIncomeDialog(double currentIncome) async {
    final controller = TextEditingController(
      text: currentIncome > 0 ? currentIncome.toStringAsFixed(2) : '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Income'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: 'RM '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (amount != null && amount >= 0) {
      ref.read(coinJarIncomeProvider.notifier).updateIncome(amount);
      if (amount == 0) {
        // Pop all coins away
        spendDownTo(0);
      } else {
        final spent = ref.read(dashboardViewModelProvider).totalSpent;
        final newBalance = (amount - spent).clamp(0.0, amount);
        final target =
            (amount > 0) ? ((newBalance / amount) * _maxCoins).round() : 0;
        resetAndDropAmount(target);
      }
    }
  }

  void _handleAddExpenseTap(double income, double balance) {
    if (income <= 0 || balance <= 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Action Required'),
          content: const Text(
              'You must add an income before you can add an expense.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseScreen(),
    ).then((_) {
      ref.read(dashboardViewModelProvider.notifier).refresh().then((_) {
        final currentIncome = ref.read(coinJarIncomeProvider);
        final spent = ref.read(dashboardViewModelProvider).totalSpent;
        final newBalance = (currentIncome - spent).clamp(0.0, currentIncome);
        final target = (currentIncome > 0)
            ? ((newBalance / currentIncome) * _maxCoins).round()
            : 0;
        spendDownTo(target);
      });
    });
  }

  // ─── Build ────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final income = ref.watch(coinJarIncomeProvider);
    final spent = ref.watch(dashboardViewModelProvider).totalSpent;
    final balance = (income - spent).clamp(0.0, income > 0 ? income : 0.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F3),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final newSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_simSize != newSize) {
            _simSize = newSize;
          }

          return Stack(
            children: [
              // ── Physics canvas + drag gesture ────────────────
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onDragStart,
                  onPanUpdate: _onDragUpdate,
                  onPanEnd: _onDragEnd,
                  onPanCancel: _onDragCancel,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CoinPainter(_coins, repaint: _frame),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),

              // ── UI layer ───────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _RoundedButton(
                            color: const Color(0xFF333C4A),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 20),
                            onTap: () => Navigator.pop(context),
                          ),
                          Row(
                            children: [
                              const Text(
                                'Add Expense',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF333C4A)),
                              ),
                              const SizedBox(width: 12),
                              _RoundedButton(
                                color: const Color(0xFFFF8252),
                                shadow: true,
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 24),
                                onTap: () =>
                                    _handleAddExpenseTap(income, balance),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      // Balance label
                      const Row(
                        children: [
                          Icon(Icons.star, color: Color(0xFFFF8252), size: 12),
                          SizedBox(width: 8),
                          Text(
                            'OVERALL BALANCE',
                            style: TextStyle(
                              color: Color(0xFFFF8252),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.star, color: Color(0xFFFF8252), size: 12),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tappable balance number
                      GestureDetector(
                        onTap: () => _showUpdateIncomeDialog(income),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'RM ',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF333C4A),
                                ),
                              ),
                              TextSpan(
                                text: balance.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF333C4A),
                                  height: 1.1,
                                  letterSpacing: -2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Rounded button helper
// ─────────────────────────────────────────────
class _RoundedButton extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final bool shadow;

  const _RoundedButton({
    required this.color,
    required this.child,
    required this.onTap,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}
