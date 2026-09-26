import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const IntellivisionApp());
}

class IntellivisionApp extends StatelessWidget {
  const IntellivisionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Intellivision Controller',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101113),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE1B764),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const ControllerScreen(),
  );
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  static const _port = 55355;
  static const _pairingCodeDefault = '482731';
  static const _keyBitStart = 7;
  static const _startBit = 19;
  static const _selectBit = 20;

  final Map<int, int> _keyTouches = {};
  final Map<int, int> _controlTouches = {};
  late final Timer _heartbeat;
  Socket? _socket;
  bool _connecting = false;
  String _connectionMessage = 'In attesa del core sul PC';
  int _buttonBits = 0;
  int _sequence = 0;
  int _axisX = 0;
  int _axisY = 0;
  int? _selectedKey;
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _codeController = TextEditingController(
    text: _pairingCodeDefault,
  );

  @override
  void initState() {
    super.initState();
    _hostController.addListener(_onHostChanged);
    _loadConnectionSettings();
    _heartbeat = Timer.periodic(const Duration(milliseconds: 20), (_) {
      _sendState();
      if (_socket == null &&
          !_connecting &&
          _hostController.text.trim().isNotEmpty) {
        _connect();
      }
    });
  }

  void _onHostChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadConnectionSettings() async {
    const channel = MethodChannel('intellivision_controller/preferences');
    try {
      final values = await channel.invokeMapMethod<String, String>('getAll');
      if (!mounted || values == null) return;
      _hostController.text = values['host'] ?? '';
      _codeController.text = values['code'] ?? _pairingCodeDefault;
      if (_hostController.text.trim().isNotEmpty) _connect();
    } on PlatformException {
      // Settings can be entered manually if persistence is unavailable.
    }
  }

  Future<void> _connect() async {
    if (_connecting || !mounted || _hostController.text.trim().isEmpty) return;
    _connecting = true;
    if (mounted) setState(() => _connectionMessage = 'Connessione al PC…');
    try {
      final socket = await Socket.connect(
        _hostController.text.trim(),
        _port,
        timeout: const Duration(seconds: 2),
      );
      if (!mounted) {
        socket.destroy();
        return;
      }
      _socket?.destroy();
      _socket = socket;
      socket.add(
        Uint8List.fromList('${_codeController.text.trim()}\n'.codeUnits),
      );
      setState(() => _connectionMessage = 'Collegato al core FreeIntv');
      socket.done.then((_) => _connectionEnded(socket));
      socket.listen(
        (_) {},
        onError: (_) => _connectionEnded(socket),
        onDone: () => _connectionEnded(socket),
        cancelOnError: true,
      );
      _sendState();
    } on SocketException {
      if (mounted) {
        setState(() => _connectionMessage = 'Core non raggiungibile');
      }
    } on TimeoutException {
      if (mounted) setState(() => _connectionMessage = 'Connessione scaduta');
    } finally {
      _connecting = false;
    }
  }

  void _connectToHost() {
    _socket?.destroy();
    _socket = null;
    const channel = MethodChannel('intellivision_controller/preferences');
    channel
        .invokeMethod<void>('setAll', <String, String>{
          'host': _hostController.text.trim(),
          'code': _codeController.text.trim(),
        })
        .catchError((Object _) {});
    _connect();
  }

  void _connectionEnded(Socket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    if (mounted) setState(() => _connectionMessage = 'Connessione interrotta');
  }

  void _sendState() {
    final socket = _socket;
    if (socket == null) return;
    final packet = Uint8List(16);
    packet.setRange(0, 4, const [0x46, 0x49, 0x56, 0x31]); // FIV1
    final data = ByteData.sublistView(packet);
    data.setUint32(4, _sequence++, Endian.little);
    data.setUint32(8, _buttonBits, Endian.little);
    data.setInt16(12, _axisX, Endian.little);
    data.setInt16(14, _axisY, Endian.little);
    try {
      socket.add(packet);
    } on SocketException {
      _connectionEnded(socket);
    }
  }

  void _pressKey(int pointer, int index) {
    _keyTouches[pointer] = index;
    _selectedKey = index;
    _rebuildKeypadBits();
  }

  void _releaseKey(int pointer) {
    _keyTouches.remove(pointer);
    _selectedKey = _keyTouches.isEmpty ? null : _keyTouches.values.last;
    _rebuildKeypadBits();
  }

  void _rebuildKeypadBits() {
    const keyMask = 0xFFF << _keyBitStart;
    _buttonBits &= ~keyMask;
    final key = _selectedKey;
    if (key != null) _buttonBits |= 1 << (_keyBitStart + key);
    if (mounted) setState(() {});
  }

  void _controlDown(int pointer, int bit) {
    _controlTouches[pointer] = bit;
    _buttonBits |= 1 << bit;
    setState(() {});
  }

  void _controlUp(int pointer) {
    final bit = _controlTouches.remove(pointer);
    if (bit != null && !_controlTouches.values.contains(bit)) {
      _buttonBits &= ~(1 << bit);
    }
    setState(() {});
  }

  void _setDisc(Offset value) {
    setState(() {
      _axisX = (value.dx.clamp(-1.0, 1.0) * 32767).round();
      // Keep screen coordinates: the core's disc map expects negative Y for up.
      _axisY = (value.dy.clamp(-1.0, 1.0) * 32767).round();
    });
  }

  void _resetDisc() => _setDisc(Offset.zero);

  @override
  void dispose() {
    _heartbeat.cancel();
    final socket = _socket;
    if (socket != null) {
      _buttonBits = 0;
      _axisX = 0;
      _axisY = 0;
      _sendState();
      socket.destroy();
    }
    _hostController.removeListener(_onHostChanged);
    _hostController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _socket != null;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = connected || constraints.maxHeight < 680;
            // Keep the keypad's touch targets in a fixed 3×4 grid, matching
            // the physical panel so future ROM overlays can align to it.
            final buttonSize = math
                .min(88.0, (constraints.maxWidth - 116) / 3)
                .clamp(68.0, 88.0);
            return Column(
              children: [
                if (!connected)
                  _TopBar(
                    connected: connected,
                    message: _connectionMessage,
                    onRetry: _connect,
                  ),
                if (!connected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hostController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _connectToHost(),
                            decoration: const InputDecoration(
                              labelText: 'Indirizzo IP del PC',
                              hintText: 'es. 192.168.1.20',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Codice',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: _connectToHost,
                          icon: const Icon(Icons.link),
                          tooltip: 'Connetti',
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: connected
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 470,
                                ),
                                child: _controllerFace(compact, buttonSize),
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 470),
                              child: Container(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 18 : 24,
                                  compact ? 14 : 22,
                                  compact ? 18 : 24,
                                  compact ? 16 : 24,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(38),
                                  border: Border.all(
                                    color: const Color(0xFF6A6256),
                                  ),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF343332),
                                      Color(0xFF171819),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 30,
                                      offset: Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _BrandPlate(),
                                    SizedBox(height: compact ? 12 : 20),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'KEYPAD',
                                        style: TextStyle(
                                          color: Color(0xFFB6AA96),
                                          fontSize: 10,
                                          letterSpacing: 2.2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: const Color(0xFF131313),
                                        border: Border.all(color: Colors.black),
                                      ),
                                      child: _Keypad(
                                        buttonSize: buttonSize,
                                        selectedKey: _selectedKey,
                                        onDown: _pressKey,
                                        onUp: _releaseKey,
                                      ),
                                    ),
                                    SizedBox(height: compact ? 12 : 20),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _Disc(
                                            diameter: compact ? 158 : 206,
                                            axis: Offset(
                                              _axisX / 32767,
                                              _axisY / 32767,
                                            ),
                                            onChanged: _setDisc,
                                            onReleased: _resetDisc,
                                          ),
                                          SizedBox(width: compact ? 14 : 24),
                                          Column(
                                            children: [
                                              _RoundAction(
                                                label: 'TOP',
                                                color: const Color(0xFFD8B467),
                                                pressed: _isPressed(6),
                                                onDown: (id) =>
                                                    _controlDown(id, 6),
                                                onUp: _controlUp,
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  _RoundAction(
                                                    label: 'LEFT',
                                                    color: const Color(
                                                      0xFFC97850,
                                                    ),
                                                    pressed: _isPressed(4),
                                                    onDown: (id) =>
                                                        _controlDown(id, 4),
                                                    onUp: _controlUp,
                                                  ),
                                                  const SizedBox(width: 9),
                                                  _RoundAction(
                                                    label: 'RIGHT',
                                                    color: const Color(
                                                      0xFFB95542,
                                                    ),
                                                    pressed: _isPressed(5),
                                                    onDown: (id) =>
                                                        _controlDown(id, 5),
                                                    onUp: _controlUp,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: compact ? 12 : 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _UtilityButton(
                                          label: 'PAUSE',
                                          pressed: _isPressed(_startBit),
                                          onDown: (id) =>
                                              _controlDown(id, _startBit),
                                          onUp: _controlUp,
                                        ),
                                        const SizedBox(width: 14),
                                        _UtilityButton(
                                          label: 'SWAP',
                                          pressed: _isPressed(_selectBit),
                                          onDown: (id) =>
                                              _controlDown(id, _selectBit),
                                          onUp: _controlUp,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (!connected) const _UsbHelp(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _controllerFace(bool compact, double buttonSize) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 470),
    child: Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 14 : 22,
        compact ? 18 : 24,
        compact ? 16 : 24,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: const Color(0xFF6A6256)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF343332), Color(0xFF171819)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UtilityButton(
                label: 'PAUSE',
                pressed: _isPressed(_startBit),
                onDown: (id) => _controlDown(id, _startBit),
                onUp: _controlUp,
              ),
              const SizedBox(width: 14),
              _UtilityButton(
                label: 'SWAP',
                pressed: _isPressed(_selectBit),
                onDown: (id) => _controlDown(id, _selectBit),
                onUp: _controlUp,
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 20),
          const _BrandPlate(),
          SizedBox(height: compact ? 12 : 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'KEYPAD',
              style: TextStyle(
                color: Color(0xFFB6AA96),
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF131313),
              border: Border.all(color: Colors.black),
            ),
            child: _Keypad(
              buttonSize: buttonSize,
              selectedKey: _selectedKey,
              onDown: _pressKey,
              onUp: _releaseKey,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Disc(
                  diameter: compact ? 196 : 240,
                  axis: Offset(_axisX / 32767, _axisY / 32767),
                  onChanged: _setDisc,
                  onReleased: _resetDisc,
                ),
                SizedBox(width: compact ? 14 : 24),
                Column(
                  children: [
                    _RoundAction(
                      label: 'TOP',
                      color: const Color(0xFFD8B467),
                      pressed: _isPressed(6),
                      onDown: (id) => _controlDown(id, 6),
                      onUp: _controlUp,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _RoundAction(
                          label: 'LEFT',
                          color: const Color(0xFFC97850),
                          pressed: _isPressed(4),
                          onDown: (id) => _controlDown(id, 4),
                          onUp: _controlUp,
                        ),
                        const SizedBox(width: 9),
                        _RoundAction(
                          label: 'RIGHT',
                          color: const Color(0xFFB95542),
                          pressed: _isPressed(5),
                          onDown: (id) => _controlDown(id, 5),
                          onUp: _controlUp,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  bool _isPressed(int bit) => (_buttonBits & (1 << bit)) != 0;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.connected,
    required this.message,
    required this.onRetry,
  });

  final bool connected;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected
                ? const Color(0xFF76CF91)
                : const Color(0xFFE0A55C),
            boxShadow: [
              BoxShadow(
                color:
                    (connected
                            ? const Color(0xFF76CF91)
                            : const Color(0xFFE0A55C))
                        .withValues(alpha: .4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INTELLIVISION CONTROLLER',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                message,
                style: const TextStyle(fontSize: 11, color: Color(0xFFAAA7A1)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Riprova connessione',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );
}

class _BrandPlate extends StatelessWidget {
  const _BrandPlate();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF615C54)),
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF242424),
    ),
    child: const Text(
      'MATTEL  •  INTELLIVISION',
      style: TextStyle(
        color: Color(0xFFE1D4BE),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.3,
      ),
    ),
  );
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.buttonSize,
    required this.selectedKey,
    required this.onDown,
    required this.onUp,
  });

  static const _labels = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'Clear',
    '0',
    'Enter',
  ];
  final double buttonSize;
  final int? selectedKey;
  final void Function(int pointer, int index) onDown;
  final void Function(int pointer) onUp;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(4, (row) {
      return Padding(
        padding: EdgeInsets.only(bottom: row == 3 ? 0 : buttonSize * .09),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (column) {
            final index = row * 3 + column;
            final selected = selectedKey == index;
            final special = index == 9 || index == 11;
            return Padding(
              padding: EdgeInsets.only(
                right: column == 2 ? 0 : buttonSize * .09,
              ),
              child: Listener(
                onPointerDown: (event) {
                  HapticFeedback.selectionClick();
                  onDown(event.pointer, index);
                },
                onPointerUp: (event) => onUp(event.pointer),
                onPointerCancel: (event) => onUp(event.pointer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  width: buttonSize,
                  height: buttonSize * .86,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(buttonSize * .2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? const [Color(0xFFFFE59A), Color(0xFFD1A332)]
                          : const [Color(0xFFE1C15F), Color(0xFF9B7926)],
                    ),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFE9A8)
                          : const Color(0xFF594519),
                      width: selected ? 2.4 : 1.5,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(color: Color(0x88E1B764), blurRadius: 12),
                          ]
                        : const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[index],
                    style: TextStyle(
                      color: const Color(0xFF25221D),
                      fontSize: special ? buttonSize * .145 : buttonSize * .3,
                      letterSpacing: special ? -.2 : 0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }),
  );
}

class _Disc extends StatelessWidget {
  const _Disc({
    required this.diameter,
    required this.axis,
    required this.onChanged,
    required this.onReleased,
  });

  final double diameter;
  final Offset axis;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  void _update(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .36;
    final delta = local - center;
    if (delta.distance < radius * .14) {
      onChanged(Offset.zero);
      return;
    }
    final normalized = delta / radius;
    onChanged(
      normalized.distance > 1 ? normalized / normalized.distance : normalized,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: diameter,
    height: diameter,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final maxOffset = diameter * .24;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _update(details.localPosition, size),
          onPanUpdate: (details) => _update(details.localPosition, size),
          onPanEnd: (_) => onReleased(),
          onPanCancel: onReleased,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF111213),
                  border: Border.all(color: const Color(0xFF080909), width: 5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Color(0xFF625C53),
                      blurRadius: 2,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Container(
                width: diameter * .73,
                height: diameter * .73,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-.25, -.28),
                    radius: .9,
                    colors: [
                      Color(0xFFF0E3C7),
                      Color(0xFFC5B79C),
                      Color(0xFF756B5C),
                    ],
                    stops: [0, .72, 1],
                  ),
                  border: Border.all(color: const Color(0xFF3E3932), width: 3),
                ),
              ),
              Transform.translate(
                offset: Offset(axis.dx * maxOffset, axis.dy * maxOffset),
                child: Container(
                  width: diameter * .2,
                  height: diameter * .2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD8C9AD).withValues(alpha: .8),
                    border: Border.all(
                      color: const Color(0xFF736957),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.color,
    required this.pressed,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final Color color;
  final bool pressed;
  final ValueChanged<int> onDown;
  final ValueChanged<int> onUp;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      HapticFeedback.lightImpact();
      onDown(event.pointer);
    },
    onPointerUp: (event) => onUp(event.pointer),
    onPointerCancel: (event) => onUp(event.pointer),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pressed
            ? color
            : Color.lerp(color, const Color(0xFF272727), .32),
        border: Border.all(color: const Color(0xFFD8C6A6), width: 2),
        boxShadow: pressed
            ? const [BoxShadow(color: Color(0x88E1B764), blurRadius: 12)]
            : const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 5,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    ),
  );
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.label,
    required this.pressed,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final bool pressed;
  final ValueChanged<int> onDown;
  final ValueChanged<int> onUp;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => onDown(event.pointer),
    onPointerUp: (event) => onUp(event.pointer),
    onPointerCancel: (event) => onUp(event.pointer),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: pressed ? const Color(0xFFE1B764) : const Color(0xFF252525),
        border: Border.all(color: const Color(0xFF847864)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: pressed ? const Color(0xFF1A1815) : const Color(0xFFD7C7A8),
        ),
      ),
    ),
  );
}

class _UsbHelp extends StatelessWidget {
  const _UsbHelp();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
    child: Text(
      'Collega PC e smartphone alla stessa rete Wi-Fi, poi inserisci l’IP del PC.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .48),
        fontSize: 10,
      ),
    ),
  );
}
