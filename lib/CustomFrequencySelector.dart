import 'package:flutter/material.dart';


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
  final TextEditingController _dayController = TextEditingController(text: '1');
  final TextEditingController _weekController = TextEditingController(text: '1');
  final TextEditingController _monthController = TextEditingController(text: '1');
  final TextEditingController _yearController = TextEditingController(text: '1');

  String _frequencyType = 'week'; // Default to weekly
  List<bool> _selectedDaysOfWeek = List.filled(7, false);

  // Monthly options
  String _monthlyOption = 'day'; // 'day' or 'weekday'
  int _selectedDayOfMonth = 4; // Default to 4th day
  int _selectedWeekOfMonth = 1; // Default to 1st week
  String _selectedDayOfWeek = 'Friday'; // Default to Friday

  // Yearly options
  String _yearlyOption = 'day'; // 'day' or 'weekday'
  int _selectedMonthDay = 4; // Default to 4th day
  String _selectedMonth = 'Apr'; // Default to April
  int _selectedWeekOfYear = 1; // Default to 1st week
  String _selectedDayOfWeekForYear = 'Friday'; // Default to Friday

  @override
  void initState() {
    super.initState();
    _loadInitialParams();
    // Set Friday as selected by default
    _selectedDaysOfWeek[5] = true;
  }

  void _loadInitialParams() {
    if (widget.initialParams.isNotEmpty) {
      _frequencyType = widget.initialParams['frequencyType'] ?? 'week';

      // Load the appropriate controller value
      switch (_frequencyType) {
        case 'day':
          _dayController.text = (widget.initialParams['value'] ?? 1).toString();
          break;
        case 'week':
          _weekController.text = (widget.initialParams['value'] ?? 1).toString();
          break;
        case 'month':
          _monthController.text = (widget.initialParams['value'] ?? 1).toString();
          _monthlyOption = widget.initialParams['monthlyOption'] ?? 'day';
          _selectedDayOfMonth = widget.initialParams['dayOfMonth'] ?? 4;
          _selectedWeekOfMonth = widget.initialParams['weekOfMonth'] ?? 1;
          _selectedDayOfWeek = widget.initialParams['dayOfWeek'] ?? 'Friday';
          break;
        case 'year':
          _yearController.text = (widget.initialParams['value'] ?? 1).toString();
          _yearlyOption = widget.initialParams['yearlyOption'] ?? 'day';
          _selectedMonthDay = widget.initialParams['monthDay'] ?? 4;
          _selectedMonth = widget.initialParams['month'] ?? 'Apr';
          _selectedWeekOfYear = widget.initialParams['weekOfYear'] ?? 1;
          _selectedDayOfWeekForYear = widget.initialParams['dayOfWeekForYear'] ?? 'Friday';
          break;
      }

      if (widget.initialParams['daysOfWeek'] != null) {
        _selectedDaysOfWeek = List<bool>.from(widget.initialParams['daysOfWeek']);
      }
    }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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

                    // Day Option
                    _buildFrequencyOption(
                      'day',
                      'Every',
                      'day',
                      _dayController,
                    ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 40),

                    // Week Option
                    _buildFrequencyOption(
                      'week',
                      'Every',
                      'week',
                      _weekController,
                    ),

                    // Days of week selector - only visible when week is selected
                    if (_frequencyType == 'week')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, left: 60.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDayCircle('S', 0, colorScheme.error),
                            _buildDayCircle('M', 1, colorScheme.onSurface),
                            _buildDayCircle('T', 2, colorScheme.onSurface),
                            _buildDayCircle('W', 3, colorScheme.onSurface),
                            _buildDayCircle('T', 4, colorScheme.onSurface),
                            _buildDayCircle('F', 5, colorScheme.primary),
                            _buildDayCircle('S', 6, colorScheme.onSurface),
                          ],
                        ),
                      ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 40),

                    // Month Option
                    _buildFrequencyOption(
                      'month',
                      'Every',
                      'month',
                      _monthController,
                    ),

                    // Monthly additional options
                    if (_frequencyType == 'month')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, left: 60.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day of month option
                            _buildOptionButton(
                              "Repeat on the 4th",
                              _monthlyOption == 'day' && _selectedDayOfMonth == 4,
                                  () {
                                setState(() {
                                  _monthlyOption = 'day';
                                  _selectedDayOfMonth = 4;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            // Specific day of week option
                            _buildOptionButton(
                              "Repeat on the 1st Friday",
                              _monthlyOption == 'weekday' && _selectedWeekOfMonth == 1 && _selectedDayOfWeek == 'Friday',
                                  () {
                                setState(() {
                                  _monthlyOption = 'weekday';
                                  _selectedWeekOfMonth = 1;
                                  _selectedDayOfWeek = 'Friday';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    Divider(color: colorScheme.onSurface.withOpacity(0.1), height: 40),

                    // Year Option
                    _buildFrequencyOption(
                      'year',
                      'Every',
                      'year',
                      _yearController,
                    ),

                    // Yearly additional options
                    if (_frequencyType == 'year')
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, left: 60.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Specific day of month/year option
                            _buildOptionButton(
                              "Repeat on 4th Apr",
                              _yearlyOption == 'day' && _selectedMonthDay == 4 && _selectedMonth == 'Apr',
                                  () {
                                setState(() {
                                  _yearlyOption = 'day';
                                  _selectedMonthDay = 4;
                                  _selectedMonth = 'Apr';
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            // Specific day/week of month option
                            _buildOptionButton(
                              "Repeat on the 1st Friday of Apr",
                              _yearlyOption == 'weekday' && _selectedWeekOfYear == 1 &&
                                  _selectedDayOfWeekForYear == 'Friday' && _selectedMonth == 'Apr',
                                  () {
                                setState(() {
                                  _yearlyOption = 'weekday';
                                  _selectedWeekOfYear = 1;
                                  _selectedDayOfWeekForYear = 'Friday';
                                  _selectedMonth = 'Apr';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // Bottom buttons
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
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Create custom frequency data
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
                        'value': int.tryParse(activeController.text) ?? 1,
                      };

                      // Add additional data based on frequency type
                      if (_frequencyType == 'week') {
                        customData['daysOfWeek'] = _selectedDaysOfWeek;
                      } else if (_frequencyType == 'month') {
                        customData['monthlyOption'] = _monthlyOption;
                        if (_monthlyOption == 'day') {
                          customData['dayOfMonth'] = _selectedDayOfMonth;
                        } else {
                          customData['weekOfMonth'] = _selectedWeekOfMonth;
                          customData['dayOfWeek'] = _selectedDayOfWeek;
                        }
                      } else if (_frequencyType == 'year') {
                        customData['yearlyOption'] = _yearlyOption;
                        customData['month'] = _selectedMonth;
                        if (_yearlyOption == 'day') {
                          customData['monthDay'] = _selectedMonthDay;
                        } else {
                          customData['weekOfYear'] = _selectedWeekOfYear;
                          customData['dayOfWeekForYear'] = _selectedDayOfWeekForYear;
                        }
                      }

                      // Pass the data back
                      Navigator.of(context).pop(customData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
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
        // Radio button
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

        // Text and input
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
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
            ),
            decoration: InputDecoration(
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDaysOfWeek[index] = !_selectedDaysOfWeek[index];
        });
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
          ),
        ),
      ),
    );
  }
}