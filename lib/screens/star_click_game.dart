import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/services/gamification_service.dart';

class StarClickGame extends StatefulWidget {
  const StarClickGame({super.key});

  @override
  State<StarClickGame> createState() => _StarClickGameState();
}

class _StarClickGameState extends State<StarClickGame>
    with SingleTickerProviderStateMixin {
  int _score = 0;
  int _timeLeft = 30;
  bool _isPlaying = false;
  double _starTop = 100;
  double _starLeft = 100;
  late Timer _timer;
  late AnimationController _pulseController;
  final Random _random = Random();
  final GamificationService _gamificationService = GamificationService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    if (_isPlaying) _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _timeLeft = 30;
      _isPlaying = true;
    });
    _moveStar();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer.cancel();
        setState(() {
          _isPlaying = false;
          _isSaving = true;
        });
        _saveScore();
      }
    });
  }

  Future<void> _saveScore() async {
    if (_score > 0) {
      String badgeName = '';
      if (_score >= 100) {
        badgeName = 'Star Master';
      } else if (_score >= 50)
        badgeName = 'Star Hunter';

      await _gamificationService.awardPoints(
        points: _score * 10,
        reason: 'Daily Star Catch Challenge',
      );
    }
    setState(() => _isSaving = false);
    _showGameOverDialog();
  }

  void _moveStar() {
    if (!_isPlaying) return;

    final size = MediaQuery.of(context).size;
    final double appBarHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;

    setState(() {
      _starTop =
          _random.nextDouble() * (size.height - appBarHeight - 200) +
          appBarHeight +
          50;
      _starLeft = _random.nextDouble() * (size.width - 100) + 20;
    });
  }

  void _onStarTapped() {
    if (!_isPlaying) return;
    setState(() => _score++);
    _moveStar();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Game Over!',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: AppColors.primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 80, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            Text(
              'Final Score: $_score',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You earned ${_score * 10} Health Points!',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Play Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Exit Game',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Stars/Particles (Static)
          ...List.generate(30, (index) {
            return Positioned(
              top: _random.nextDouble() * MediaQuery.of(context).size.height,
              left: _random.nextDouble() * MediaQuery.of(context).size.width,
              child: Icon(
                Icons.circle,
                size: _random.nextDouble() * 3,
                color: Colors.white.withValues(
                  alpha: _random.nextDouble() * 0.5,
                ),
              ),
            );
          }),

          // Content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const CustomBackButton(color: Colors.white),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_timeLeft'
                              's',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'SCORE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isPlaying && _timeLeft == 30)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 100,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Star Catch Challenge',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12,
                            ),
                            child: Text(
                              'Tap as many stars as you can in 30 seconds to earn Health Points!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'START GAME',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // The Active Star
          if (_isPlaying)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _starTop,
              left: _starLeft,
              child: GestureDetector(
                onTap: _onStarTapped,
                child: ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.2).animate(_pulseController),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFD700),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 60,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
