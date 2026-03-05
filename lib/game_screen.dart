import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'game_map.dart';
import 'game_painter.dart';
import 'score_display.dart';
import 'win_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  double pacmanX = 1.0;
  double pacmanY = 1.0;
  int score = 0;
  String direction = 'right';
  late Timer gameTimer;
  bool gameRunning = true;
  bool gameStarted = false;
  String? nextDirection; // Dirección en espera para el giro suave

  // Estado del Fantasma
  double ghostX = 7.0;
  double ghostY = 8.0;
  String ghostDirection = 'up';

  void initState() {
    super.initState();
    GameMap.resetMap();
    gameTimer = Timer.periodic(Duration(milliseconds: kGameSpeedMs.toInt()), (
      timer,
    ) {
      if (gameStarted && gameRunning) {
        movePacman();
        moveGhost();
        checkCollisions();
      }
    });
  }

  void startGame() {
    setState(() {
      gameStarted = true;
      gameRunning = true;
    });
  }

  @override
  void dispose() {
    gameTimer.cancel();
    super.dispose();
  }

  void resetGame() {
    setState(() {
      pacmanX = 1.0;
      pacmanY = 1.0;
      ghostX = 7.0;
      ghostY = 8.0;
      score = 0;
      direction = 'right';
      nextDirection = null;
      gameRunning = true;
      gameStarted = false;
      GameMap.resetMap();
    });
  }

  void movePacman() {
    setState(() {
      double step = 0.25;

      // Lógica de Tolerancia de Giro (Cornering)
      if (nextDirection != null) {
        // Verificar si estamos cerca del centro de un bloque para girar
        double diffX = (pacmanX - pacmanX.round()).abs();
        double diffY = (pacmanY - pacmanY.round()).abs();

        if (diffX < 0.3 && diffY < 0.3) {
          // Intentar cambiar a la dirección en espera
          if (canMoveIn(
            nextDirection!,
            pacmanX.round().toDouble(),
            pacmanY.round().toDouble(),
          )) {
            pacmanX = pacmanX.round().toDouble();
            pacmanY = pacmanY.round().toDouble();
            direction = nextDirection!;
            nextDirection = null;
          }
        }
      }

      double nextX = pacmanX;
      double nextY = pacmanY;

      switch (direction) {
        case 'right':
          nextX += step;
          break;
        case 'left':
          nextX -= step;
          break;
        case 'up':
          nextY -= step;
          break;
        case 'down':
          nextY += step;
          break;
      }

      if (canMoveIn(direction, nextX, nextY)) {
        pacmanX = nextX;
        pacmanY = nextY;

        // Recoger puntos
        int gridX = (pacmanX + 0.5).floor();
        int gridY = (pacmanY + 0.5).floor();

        if (gridX >= 0 &&
            gridX < kMapWidth &&
            gridY >= 0 &&
            gridY < kMapHeight) {
          final cell = GameMap.layout[gridY][gridX];
          if (cell == 2) {
            GameMap.layout[gridY][gridX] = 0;
            score += kNormalDotPoints;
          } else if (cell == 3) {
            GameMap.layout[gridY][gridX] = 0;
            score += kPowerDotPoints;
          }
        }

        checkWinCondition();
      }
    });
  }

  bool canMoveIn(String dir, double nX, double nY) {
    double margin = 0.1;
    int left = (nX + margin).floor();
    int right = (nX + 1 - margin).floor();
    int top = (nY + margin).floor();
    int bottom = (nY + 1 - margin).floor();

    return !GameMap.isWall(left, top) &&
        !GameMap.isWall(right, top) &&
        !GameMap.isWall(left, bottom) &&
        !GameMap.isWall(right, bottom);
  }

  void moveGhost() {
    double ghostStep = 0.20; // Fantasma un poco más lento

    // Si está en el centro, decidir dirección aleatoria
    double diffX = (ghostX - ghostX.round()).abs();
    double diffY = (ghostY - ghostY.round()).abs();

    if (diffX < 0.1 && diffY < 0.1) {
      ghostX = ghostX.round().toDouble();
      ghostY = ghostY.round().toDouble();

      List<String> validDirs = [];
      for (String d in ['up', 'down', 'left', 'right']) {
        double testX = ghostX;
        double testY = ghostY;
        if (d == 'up') testY -= 0.5;
        if (d == 'down') testY += 0.5;
        if (d == 'left') testX -= 0.5;
        if (d == 'right') testX += 0.5;

        if (canMoveIn(d, testX, testY)) {
          // No volver atrás inmediatamente si hay más opciones
          if (validDirs.length > 0 && isOpposite(d, ghostDirection)) continue;
          validDirs.add(d);
        }
      }

      if (validDirs.isNotEmpty) {
        ghostDirection = (validDirs..shuffle()).first;
      }
    }

    double nextGX = ghostX;
    double nextGY = ghostY;
    switch (ghostDirection) {
      case 'right':
        nextGX += ghostStep;
        break;
      case 'left':
        nextGX -= ghostStep;
        break;
      case 'up':
        nextGY -= ghostStep;
        break;
      case 'down':
        nextGY += ghostStep;
        break;
    }

    if (canMoveIn(ghostDirection, nextGX, nextGY)) {
      ghostX = nextGX;
      ghostY = nextGY;
    } else {
      // Si choca, forzar cambio de dirección en el siguiente tick
      ghostX = ghostX.round().toDouble();
      ghostY = ghostY.round().toDouble();
    }
  }

  bool isOpposite(String d1, String d2) {
    if (d1 == 'up' && d2 == 'down') return true;
    if (d1 == 'down' && d2 == 'up') return true;
    if (d1 == 'left' && d2 == 'right') return true;
    if (d1 == 'right' && d2 == 'left') return true;
    return false;
  }

  void checkCollisions() {
    double dist = (pacmanX - ghostX).abs() + (pacmanY - ghostY).abs();
    if (dist < 0.7) {
      setState(() {
        gameRunning = false;
        _showGameOverDialog();
      });
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'GAME OVER',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Un fantasma te ha atrapado.\nPuntaje: $score',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resetGame();
            },
            child: const Text(
              'REINTENTAR',
              style: TextStyle(color: Colors.yellow),
            ),
          ),
        ],
      ),
    );
  }

  void checkWinCondition() {
    bool allDotsEaten = true;
    for (int y = 0; y < kMapHeight; y++) {
      for (int x = 0; x < kMapWidth; x++) {
        if (GameMap.layout[y][x] == 2 || GameMap.layout[y][x] == 3) {
          allDotsEaten = false;
          break;
        }
      }
      if (!allDotsEaten) break;
    }

    if (allDotsEaten) {
      gameRunning = false;
      showWinDialog(context, score, resetGame);
    }
  }

  void changeDirection(String newDirection) {
    setState(() {
      nextDirection = newDirection; // Guardar como próxima dirección deseada

      // Si ya puede girar inmediatamente (está alineado), hacerlo
      if (canMoveIn(newDirection, pacmanX, pacmanY)) {
        direction = newDirection;
        nextDirection = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      autofocus: true,
      focusNode: FocusNode()..requestFocus(),
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent && gameRunning) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            changeDirection('right');
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            changeDirection('left');
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            changeDirection('up');
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            changeDirection('down');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            ScoreDisplay(score: score, onReset: resetGame),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 350,
                      height: 450,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: CustomPaint(
                        painter: GamePainter(
                          pacmanX: pacmanX,
                          pacmanY: pacmanY,
                          direction: direction,
                          ghostX: ghostX,
                          ghostY: ghostY,
                          ghostColor: Colors.red,
                        ),
                      ),
                    ),
                    if (!gameStarted)
                      Container(
                        color: Colors.black54,
                        width: 350,
                        height: 450,
                        child: Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: startGame,
                            child: const Text('INICIAR JUEGO'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Panel de Control (D-Pad)
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0, top: 10),
              child: Column(
                children: [
                  // Botón Arriba
                  _buildControlBtn(Icons.keyboard_arrow_up, 'up'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlBtn(Icons.keyboard_arrow_left, 'left'),
                      const SizedBox(width: 20),
                      // Botón Abajo en el centro para seguir el diagrama del usuario
                      _buildControlBtn(Icons.keyboard_arrow_down, 'down'),
                      const SizedBox(width: 20),
                      _buildControlBtn(Icons.keyboard_arrow_right, 'right'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String dir) {
    return GestureDetector(
      onTap: () => changeDirection(dir),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.yellow.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.yellow, size: 40),
      ),
    );
  }
}
