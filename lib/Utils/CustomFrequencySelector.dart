import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomFrequencySelector extends StatefulWidget {
  final Map<String, dynamic> initialParams;
  const CustomFrequencySelector({
    Key? key,
    this.initialParams = const {},
  }) : super(key: key);
  @override
  State<CustomFrequencySelector> createState() => _CustomFrequencySelectorState();
}

class _CustomFrequencySelectorState extends State<CustomFrequencySelector> {
  late TextEditingController _dayController;
  late TextEditingController _weekController;
  late TextEditingController _monthController;
  late TextEditingController _yearController;
  late String _frequencyType;
  late List<bool> _selectedDaysOfWeek;
  late List<int> _selectedDates;
  bool _showDateSelection = false;
  late DateTime _currentDate;
  late int _currentDayOfMonth;
  late String _currentMonth;
  late String _currentDayOfWeek;
  late int _currentWeekOfMonth;

  late String _monthlyOption;
  late int _selectedDayOfMonth;
  late int _selectedWeekOfMonth;
  late String _selectedDayOfWeek;

  late String _yearlyOption;
  late int _selectedMonthDay;
  late String _selectedMonth;
  late int _selectedWeekOfYear;
  late String _selectedDayOfWeekForYear;
  late List<bool> _selectedMonths;
  bool _showMonthSelection = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultValues();
    _loadInitialParams();
  }

  void _initializeDefaultValues() {
    _currentDate = DateTime.now();
    _currentDayOfMonth = _currentDate.day;
    _currentMonth = _getMonthAbbreviation(_currentDate.month);
    _currentDayOfWeek = _getDayOfWeekName(_currentDate.weekday);
    _currentWeekOfMonth = (_currentDate.day / 7).ceil();
    _frequencyType = 'week';
    _dayController = TextEditingController(text: '1');
    _weekController = TextEditingController(text: '1');
    _monthController = TextEditingController(text: '1');
    _yearController = TextEditingController(text: '1');
    _selectedDaysOfWeek = List.filled(7, false);
    int currentWeekday = _convertWeekdayToUIIndex(_currentDate.weekday);
    _selectedDaysOfWeek[currentWeekday] = true;
    _monthlyOption = 'day';
    _selectedDayOfMonth = _currentDayOfMonth;
    _selectedWeekOfMonth = _currentWeekOfMonth;
    _selectedDayOfWeek = _currentDayOfWeek;
    _selectedDates = [_currentDayOfMonth];
    _yearlyOption = 'day';
    _selectedMonthDay = _currentDayOfMonth;
    _selectedMonth = _currentMonth;
    _selectedWeekOfYear = _currentWeekOfMonth;
    _selectedDayOfWeekForYear = _currentDayOfWeek;
    _selectedMonths = List.filled(12, false);
    _selectedMonths[_currentDate.month - 1] = true;
  }

  int _convertWeekdayToUIIndex(int dateTimeWeekday) {
    // Convert DateTime.weekday (Monday = 1, Sunday = 7) to UI index (Sunday = 0)
    // DateTime: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
    // UI:       Sun=0, Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6
    return dateTimeWeekday % 7;
  }
  String _getMonthAbbreviation(int month) {
    const monthAbbreviations = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
    return monthAbbreviations[month - 1];
  }

  String _getDayOfWeekName(int weekday) {
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return dayNames[weekday - 1];
  }
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) {
      return 'th';
    }

    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  void _loadInitialParams() {
    if (widget.initialParams.isNotEmpty) {
      setState(() {
        _frequencyType = widget.initialParams['frequencyType'] ?? 'week';

        switch (_frequencyType) {
          case 'day':
            int value = widget.initialParams['value'] ?? 1;
            _dayController.text = value.toString();
            break;
          case 'week':
            int value = widget.initialParams['value'] ?? 1;
            _weekController.text = value.toString();
            if (widget.initialParams['daysOfWeek'] != null) {
              _selectedDaysOfWeek = List<bool>.from(widget.initialParams['daysOfWeek']);
            }
            break;
          case 'month':
            int value = widget.initialParams['value'] ?? 1;
            _monthController.text = value.toString();
            _monthlyOption = widget.initialParams['monthlyOption'] ?? 'day';

            if (_monthlyOption == 'day') {
              _selectedDayOfMonth = widget.initialParams['dayOfMonth'] ?? _currentDayOfMonth;
            } else if (_monthlyOption == 'weekday') {
              _selectedWeekOfMonth = widget.initialParams['weekOfMonth'] ?? _currentWeekOfMonth;
              _selectedDayOfWeek = widget.initialParams['dayOfWeek'] ?? _currentDayOfWeek;
            } else if (_monthlyOption == 'dates') {
              if (widget.initialParams['selectedDates'] != null) {
                _selectedDates = List<int>.from(widget.initialParams['selectedDates']);
              }
              _showDateSelection = true;
            }
            break;
          case 'year':
            int value = widget.initialParams['value'] ?? 1;
            _yearController.text = value.toString();
            _yearlyOption = widget.initialParams['yearlyOption'] ?? 'day';

            if (_yearlyOption == 'day') {
              _selectedMonthDay = widget.initialParams['monthDay'] ?? _currentDayOfMonth;
            } else {
              _selectedWeekOfYear = widget.initialParams['weekOfYear'] ?? _currentWeekOfMonth;
              _selectedDayOfWeekForYear = widget.initialParams['dayOfWeekForYear'] ?? _currentDayOfWeek;
            }

            _selectedMonth = widget.initialParams['month'] ?? _currentMonth;

            if (widget.initialParams['selectedMonths'] != null) {
              _selectedMonths = List<bool>.from(widget.initialParams['selectedMonths']);
              if (_selectedMonths.contains(true)) {
                _showMonthSelection = true;
              }
            }
            break;
        }
      });
    }
  }

  void _toggleDateSelection(int date) {
    setState(() {
      if (_selectedDates.contains(date)) {
        // Only remove if it's not the last selected date
        if (_selectedDates.length > 1) {
          _selectedDates.remove(date);
        }
      } else {
        _selectedDates.add(date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildFrequencyOption(
                      'day',
                      'Every',
                      'day',
                      _dayController,
                    ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 40),
                    _buildFrequencyOption(
                      'week',
                      'Every',
                      'week',
                      _weekController,
                    ),
                    if (_frequencyType == 'week')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, left: 60.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDayCircle('S', 0, colorScheme.onSurface),
                            _buildDayCircle('M', 1, colorScheme.onSurface),
                            _buildDayCircle('T', 2, colorScheme.onSurface),
                            _buildDayCircle('W', 3, colorScheme.onSurface),
                            _buildDayCircle('T', 4, colorScheme.onSurface),
                            _buildDayCircle('F', 5, colorScheme.onSurface),
                            _buildDayCircle('S', 6, colorScheme.onSurface),
                          ],
                        ),
                      ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 40),
                    _buildFrequencyOption(
                      'month',
                      'Every',
                      'month',
                      _monthController,
                    ),
                    if (_frequencyType == 'month')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildOptionButton(
                              "Repeat on the $_selectedDayOfMonth${_getOrdinalSuffix(_selectedDayOfMonth)}",
                              _monthlyOption == 'day',
                                  () {
                                setState(() {
                                  _monthlyOption = 'day';
                                  _selectedDayOfMonth = _currentDayOfMonth;
                                  _showDateSelection = false;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildOptionButton(
                              "Repeat on the $_selectedWeekOfMonth${_getOrdinalSuffix(_selectedWeekOfMonth)} $_selectedDayOfWeek",
                              _monthlyOption == 'weekday',
                                  () {
                                setState(() {
                                  _monthlyOption = 'weekday';
                                  _selectedWeekOfMonth = _currentWeekOfMonth;
                                  _selectedDayOfWeek = _currentDayOfWeek;
                                  _showDateSelection = false;
                                });
                              },
                            ),

                            const SizedBox(height: 12),
                            _buildOptionButton(
                              "Select dates to repeat",
                              _monthlyOption == 'dates',
                                  () {
                                setState(() {
                                  _monthlyOption = 'dates';
                                  _showDateSelection = true;
                                });
                              },
                            ),
                            if (_showDateSelection)
                              Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: _buildDateSelectionGrid(colorScheme),
                              ),
                          ],
                        ),
                      ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 40),
                    _buildFrequencyOption(
                      'year',
                      'Every',
                      'year',
                      _yearController,
                    ),
                    if (_frequencyType == 'year')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildOptionButton(
                              "Repeat on $_selectedMonthDay${_getOrdinalSuffix(_selectedMonthDay)} $_selectedMonth",
                              _yearlyOption == 'day',
                                  () {
                                setState(() {
                                  _yearlyOption = 'day';
                                  _selectedMonthDay = _currentDayOfMonth;
                                  _selectedMonth = _currentMonth;
                                });
                              },
                            ),

                            const SizedBox(height: 12),
                            _buildOptionButton(
                              "Repeat on the $_selectedWeekOfYear${_getOrdinalSuffix(_selectedWeekOfYear)} $_selectedDayOfWeekForYear of $_selectedMonth",
                              _yearlyOption == 'weekday',
                                  () {
                                setState(() {
                                  _yearlyOption = 'weekday';
                                  _selectedWeekOfYear = _currentWeekOfMonth;
                                  _selectedDayOfWeekForYear = _currentDayOfWeek;
                                  _selectedMonth = _currentMonth;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            _buildMonthSelectionButton(colorScheme),

                            if (_showMonthSelection)
                              _buildMonthSelectionGrid(colorScheme),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      TextEditingController activeController;
                      switch (_frequencyType) {
                        case 'day':
                          activeController = _dayController;
                          break;
                        case 'week':
                          activeController = _weekController;
                          break;
                        case 'month':
                          activeController = _monthController;
                          break;
                        case 'year':
                          activeController = _yearController;
                          break;
                        default:
                          activeController = _dayController;
                      }
                      Map<String, dynamic> customData = {
                        'frequencyType': _frequencyType,
                        'value': validateNumericInput(activeController.text),
                      };
                      if (_frequencyType == 'week') {
                        customData['daysOfWeek'] = _selectedDaysOfWeek;
                      } else if (_frequencyType == 'month') {
                        customData['monthlyOption'] = _monthlyOption;
                        if (_monthlyOption == 'day') {
                          customData['dayOfMonth'] = _selectedDayOfMonth;
                        } else if (_monthlyOption == 'weekday') {
                          customData['weekOfMonth'] = _selectedWeekOfMonth;
                          customData['dayOfWeek'] = _selectedDayOfWeek;
                        } else if (_monthlyOption == 'dates') {
                          customData['selectedDates'] = _selectedDates;
                        }
                      } else if (_frequencyType == 'year') {
                        customData['yearlyOption'] = _yearlyOption;
                        customData['month'] = _selectedMonth;
                        customData['selectedMonths'] = _selectedMonths;
                        if (_yearlyOption == 'day') {
                          customData['monthDay'] = _selectedMonthDay;
                        } else {
                          customData['weekOfYear'] = _selectedWeekOfYear;
                          customData['dayOfWeekForYear'] = _selectedDayOfWeekForYear;
                        }
                      }
                      Navigator.of(context).pop(customData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'SAVE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelectionButton(ColorScheme colorScheme) {
    final int selectedCount = _selectedMonths.where((isSelected) => isSelected).length;
    final String dayText = _yearlyOption == 'day'
        ? "$_selectedMonthDay${_getOrdinalSuffix(_selectedMonthDay)} day"
        : "the $_selectedWeekOfYear${_getOrdinalSuffix(_selectedWeekOfYear)} $_selectedDayOfWeekForYear";

    return GestureDetector(
      onTap: () {
        setState(() {
          _showMonthSelection = !_showMonthSelection;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: _showMonthSelection ? colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: _showMonthSelection ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          selectedCount == 1
              ? "Select months to repeat on $dayText"
              : "Repeat on $dayText in $selectedCount months",
          style: TextStyle(
            color: _showMonthSelection ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.8),
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMonthSelectionGrid(ColorScheme colorScheme) {
    const List<String> monthsAbbrv = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEPT', 'OCT', 'NOV', 'DEC'];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final bool isSelected = _selectedMonths[index];
              final bool isLastSelected = isSelected && _selectedMonths.where((selected) => selected).length == 1;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    // Don't allow deselection if it's the last selected month
                    if (!isLastSelected) {
                      _selectedMonths[index] = !_selectedMonths[index];
                      if (_selectedMonths.where((isSelected) => isSelected).length == 1 &&
                          _selectedMonths[index]) {
                        _selectedMonth = _getMonthAbbreviation(index + 1);
                      }
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      monthsAbbrv[index],
                      style: TextStyle(
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyOption(
      String type,
      String prefix,
      String suffix,
      TextEditingController controller,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = _frequencyType == type;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _frequencyType = type;
            });
          },
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                width: 2,
              ),
              color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
            ),
            child: isSelected
                ? Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 15),
        Text(
          prefix,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          child: TextField(
            enabled: isSelected,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                final int? value = int.tryParse(newValue.text);
                if (value == null || value < 1) {
                  return oldValue.text.isEmpty ? const TextEditingValue(text: "1") : oldValue;
                }
                return newValue;
              }),
            ],
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          suffix,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCircle(String day, int index, Color textColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = _selectedDaysOfWeek[index];
    final bool isLastSelectedDay = isSelected && _selectedDaysOfWeek.where((day) => day).length == 1;

    return GestureDetector(
      onTap: () {
        if (!isLastSelectedDay) {
          setState(() {
            _selectedDaysOfWeek[index] = !_selectedDaysOfWeek[index];
          });
        }
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? colorScheme.primary : Colors.transparent,
          border: isSelected
              ? null
              : Border.all(color: colorScheme.onSurface.withOpacity(0.5), width: 1),
        ),
        child: Center(
          child: Text(
            day,
            style: TextStyle(
              color: isSelected ? colorScheme.onPrimary : textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String text, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: isSelected ? colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.8),
            fontSize: 16,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDateSelectionGrid(ColorScheme colorScheme) {
    int daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    List<int> allDays = List.generate(daysInMonth, (index) => index + 1);
    List<List<int>> rows = [];
    for (int i = 0; i < allDays.length; i += 7) {
      rows.add(allDays.sublist(i, i + 7 > allDays.length ? allDays.length : i + 7));
    }

    return Column(
      children: [
        ...rows.map((rowDays) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ...rowDays.map((day) => _buildDateCircle(day, colorScheme)),
                ...List.generate(7 - rowDays.length, (index) => const SizedBox(width: 32))
              ],
            ),
          );
        }),
      ],
    );
  }
  Widget _buildDateCircle(int day, ColorScheme colorScheme) {
    final bool isSelected = _selectedDates.contains(day);

    return GestureDetector(
      onTap: () => _toggleDateSelection(day),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _weekController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int validateNumericInput(String text) {
    final value = int.tryParse(text) ?? 1;
    return value < 1 ? 1 : value;
  }
}