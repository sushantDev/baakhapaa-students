import 'dart:async';
import 'dart:math';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:provider/provider.dart';

import '../../widgets/header.dart';

class BkpFortuneWheel extends StatefulWidget {
  static const routeName = '/bkp-fortune-wheel';

  const BkpFortuneWheel({Key? key}) : super(key: key);

  @override
  State<BkpFortuneWheel> createState() => _BkpFortuneWheelState();
}

class _BkpFortuneWheelState extends State<BkpFortuneWheel> {
  late DateTime _lastUsedTime;
  late Timer _timer;
  int _remainingTime = 0;
  static Random _random = Random();
  StreamController<int> selected = StreamController<int>();
  late List<String> _items;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _items = <String>[
      'Baakhapaa Sunglasses',
      '5 Bkp Points',
      '50rs Recharge Card',
      '5 Bkp Points',
      'Baakhapaa Tshirt',
      '20 Bkp Points',
      '10 Bkp Points',
      'Baakhapaa Joggers',
    ];
    _initPrefs();
  }

  @override
  void dispose() {
    selected.close();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    var authProvider = Provider.of<Auth>(context, listen: false);
    String lastUsedTimeString = authProvider.spinAndWinLastUsedTime as String;
    _lastUsedTime = DateTime.parse(lastUsedTimeString);
    _startTimer();
  }

  int customRandomInt(int min, int max) {
    int totalWeight = max - min + 1;
    int randomNumber = _random.nextInt(totalWeight);

    // Adjust the probabilities as per your requirement
    if (randomNumber < totalWeight * 0.2) {
      // 50% probability
      return 1;
    } else if (randomNumber < totalWeight * 0.7) {
      // 30% probability
      return 3;
    } else {
      // remaining probabilities
      // return min +
      //     _random.nextInt(max - min + 1 - 2);
      return 1;
    }
  }

  Future<void> winPoints() async {
    if (_isSpinning) return;

    var authProvider = Provider.of<Auth>(context, listen: false);
    if (DateTime.now().difference(_lastUsedTime).inDays >= 1) {
      setState(() {
        _isSpinning = true;
      });
      await authProvider
          .cooldownReset(
              platform: 'spinAndWin', dateTime: DateTime.now().toString())
          .then(
        (_) async {
          setState(() {
            _lastUsedTime = DateTime.now();
          });
          int value = customRandomInt(0, _items.length);
          setState(() {
            selected.add(value);
          });
          await authProvider
              .coinTransaction(5, 'credited', 'Spin & Win points')
              .then(
            (_) {
              Future.delayed(Duration(seconds: 5), () {
                showScaffoldMessenger(
                    context, 'Won item successfully transferred.');
                Navigator.pushReplacementNamed(context, UserScreen.routeName);
              });
            },
          );
        },
      );
    } else {
      _showTimerDialog();
    }
  }

  void _startTimer() {
    int difference =
        _lastUsedTime.add(Duration(days: 1)).millisecondsSinceEpoch -
            DateTime.now().millisecondsSinceEpoch;

    if (difference > 0) {
      _remainingTime = difference;
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingTime > 0) {
            _remainingTime -= 1000;
          } else {
            timer.cancel();
          }
        });
      });
    } else {
      // If difference is 0 or negative, reset _remainingTime and cancel the timer
      _remainingTime = 0;
    }
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Please Come Back Tomorrow'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You have already used this feature today.'),
              Text('Please come back tomorrow to spin & win again.'),
              SizedBox(height: 10),
              Text(
                  'Time remaining: ${_formatDuration(Duration(milliseconds: _remainingTime))}'),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: 'Fortune Wheel'),
      body: SingleChildScrollView(
        child: Container(
          height: 800,
          decoration: BoxDecoration(
            image: DecorationImage(
              opacity: 0.1,
              image: CachedNetworkImageProvider(
                  "${Url.mediaUrl}/assets/doodle.jpg"),
              fit: BoxFit.fill,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: <Widget>[
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => winPoints(),
                  child: Text('Spin & Win!'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFC69400)),
                ),
                Expanded(
                  child: FortuneWheel(
                    selected: selected.stream,
                    items: [
                      for (var i = 0; i < _items.length; i++)
                        FortuneItem(
                          child: Text(_items[i]),
                          style: FortuneItemStyle(
                            color: i % 2 == 0
                                ? Color(0xFFC69400)
                                : Color(0xFF9B7400),
                            borderColor: Color(0xFF9B7400),
                            borderWidth: 3,
                          ),
                        ),
                    ],
                    indicators: <FortuneIndicator>[
                      FortuneIndicator(
                        alignment: Alignment.topCenter,
                        child: TriangleIndicator(
                          color: Colors.green,
                          width: 30.0,
                          height: 30.0,
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
