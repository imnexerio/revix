package com.imnexerio.revix

import java.util.*
import kotlin.collections.ArrayList

class CalculateCustomNextDate {
    companion object {
        fun calculateCustomNextDate(startDate: Calendar, params: Map<String, Any?>): Calendar {
            // Extract custom_params if nested
            val customParams = if (params.containsKey("custom_params")) {
                @Suppress("UNCHECKED_CAST")
                params["custom_params"] as Map<String, Any?>
            } else {
                params
            }

            // Extract base parameters with safe fallbacks
            val frequencyType = (customParams["frequencyType"] as? String)?.toLowerCase(Locale.ROOT) ?: "week"
            val value = customParams["value"] as? Int ?: 1
            val nextDate = Calendar.getInstance()
            nextDate.timeInMillis = startDate.timeInMillis

//            println("Processing: frequencyType=$frequencyType, value=$value")

            when (frequencyType) {
                "day" -> {
                    // Simple day increment
                    nextDate.add(Calendar.DAY_OF_MONTH, value)
                }

                "week" -> {
                    // Get selected days of week and ensure it's the right type
                    var daysOfWeek = ArrayList<Boolean>()

                    if (customParams["daysOfWeek"] is List<*>) {
                        // Convert any list to a list of booleans
                        @Suppress("UNCHECKED_CAST")
                        val rawList = customParams["daysOfWeek"] as List<*>
                        daysOfWeek = ArrayList(rawList.map { it == true })

                        // Ensure we have exactly 7 elements
                        if (daysOfWeek.size < 7) {
                            repeat(7 - daysOfWeek.size) { daysOfWeek.add(false) }
                        } else if (daysOfWeek.size > 7) {
                            daysOfWeek = ArrayList(daysOfWeek.subList(0, 7))
                        }
                    } else {
                        daysOfWeek = ArrayList(List(7) { false })
                    }

                    // If no days selected, default to same day next week
                    if (!daysOfWeek.contains(true)) {
                        nextDate.add(Calendar.DAY_OF_MONTH, 7 * value)
                        return nextDate
                    }

                    // Find the first matching day after startDate
                    // In Calendar, Sunday is 1, Monday is 2, ..., Saturday is 7
                    // Convert to 0-6 where 0 is Sunday
                    val currentWeekday = startDate.get(Calendar.DAY_OF_WEEK) - 1
                    var foundInCurrentWeek = false

                    // First check if there are any selected days later in the current week
                    for (i in (currentWeekday + 1) until 7) {
                        if (daysOfWeek[i]) {
                            val daysToAdd = i - currentWeekday
                            nextDate.add(Calendar.DAY_OF_MONTH, daysToAdd)
                            foundInCurrentWeek = true
                            break
                        }
                    }

                    // If no selected days found later in current week, find first selected day in next week(s)
                    if (!foundInCurrentWeek) {
                        // Calculate days to Sunday (start of week)
                        val daysToFirstDayOfNextWeek = 7 - currentWeekday

                        // Start from the beginning of next week
                        val beginningOfNextWeek = Calendar.getInstance()
                        beginningOfNextWeek.timeInMillis = startDate.timeInMillis
                        beginningOfNextWeek.add(Calendar.DAY_OF_MONTH, daysToFirstDayOfNextWeek)

                        // Find the first selected day in the week
                        var daysFromSunday = 0
                        for (i in 0 until 7) {
                            if (daysOfWeek[i]) {
                                daysFromSunday = i
                                break
                            }
                        }

                        // Set next date to the found day in the next week
                        nextDate.timeInMillis = beginningOfNextWeek.timeInMillis
                        nextDate.add(Calendar.DAY_OF_MONTH, daysFromSunday)

                        // Now add additional weeks based on value
                        if (value > 1) {
                            nextDate.add(Calendar.DAY_OF_MONTH, 7 * (value - 1))
                        }
                    } else if (value > 1) {
                        // If we found a day in the current week but value > 1,
                        // add (value-1) weeks to the next occurrence
                        nextDate.add(Calendar.DAY_OF_MONTH, 7 * (value - 1))
                    }
                }

                "month" -> {
                    val monthlyOption = (customParams["monthlyOption"] as? String) ?: "day"

                    when (monthlyOption) {
                        "day" -> {
                            // Specific day of month
                            val dayOfMonth = customParams["dayOfMonth"] as? Int ?: startDate.get(Calendar.DAY_OF_MONTH)                            // Calculate the target month
                            val targetMonth = startDate.get(Calendar.MONTH) + value
                            val targetYear = startDate.get(Calendar.YEAR) + targetMonth / 12
                            val adjustedMonth = targetMonth % 12

                            // Calculate next date and handle month length issues
                            val maxDaysCalendar = Calendar.getInstance()
                            maxDaysCalendar.set(targetYear, adjustedMonth, 1)
                            val maxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                            nextDate.set(Calendar.YEAR, targetYear)
                            nextDate.set(Calendar.MONTH, adjustedMonth)
                            nextDate.set(Calendar.DAY_OF_MONTH, if (dayOfMonth > maxDays) maxDays else dayOfMonth)

                            // Check if the result is before or equal to the start date
                            if (!nextDate.after(startDate)) {
                                val newTargetMonth = startDate.get(Calendar.MONTH) + value + 1
                                val newTargetYear = startDate.get(Calendar.YEAR) + newTargetMonth / 12
                                val newAdjustedMonth = newTargetMonth % 12

                                maxDaysCalendar.set(newTargetYear, newAdjustedMonth, 1)
                                val newMaxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                                nextDate.set(Calendar.YEAR, newTargetYear)
                                nextDate.set(Calendar.MONTH, newAdjustedMonth)
                                nextDate.set(Calendar.DAY_OF_MONTH, if (dayOfMonth > newMaxDays) newMaxDays else dayOfMonth)
                            }
                        }

                        "weekday" -> {
                            // Specific weekday (e.g., "3rd Tuesday")
                            val weekOfMonth = customParams["weekOfMonth"] as? Int ?: 1
                            val dayOfWeek = (customParams["dayOfWeek"] as? String) ?: "Monday"

                            // Map dayOfWeek string to Calendar constant
                            val dayMap = mapOf(
                                "monday" to Calendar.MONDAY,
                                "mon" to Calendar.MONDAY,
                                "tuesday" to Calendar.TUESDAY,
                                "tue" to Calendar.TUESDAY,
                                "wednesday" to Calendar.WEDNESDAY,
                                "wed" to Calendar.WEDNESDAY,
                                "thursday" to Calendar.THURSDAY,
                                "thu" to Calendar.THURSDAY,
                                "friday" to Calendar.FRIDAY,
                                "fri" to Calendar.FRIDAY,
                                "saturday" to Calendar.SATURDAY,
                                "sat" to Calendar.SATURDAY,
                                "sunday" to Calendar.SUNDAY,
                                "sun" to Calendar.SUNDAY
                            )
                            val targetWeekday = dayMap[dayOfWeek.toLowerCase(Locale.ROOT)] ?: Calendar.MONDAY

                            // Calculate target month and year
                            val targetMonth = startDate.get(Calendar.MONTH) + value
                            val targetYear = startDate.get(Calendar.YEAR) + targetMonth / 12
                            val adjustedMonth = targetMonth % 12

                            // Find the first occurrence of the target weekday in the month
                            val firstDayOfMonth = Calendar.getInstance()
                            firstDayOfMonth.set(targetYear, adjustedMonth, 1)

                            // Calculate days until target weekday
                            val firstDayWeekday = firstDayOfMonth.get(Calendar.DAY_OF_WEEK)
                            var daysUntilWeekday = (targetWeekday - firstDayWeekday) % 7
                            if (daysUntilWeekday < 0) daysUntilWeekday += 7

                            // Calculate the date of the first occurrence
                            val firstOccurrence = Calendar.getInstance()
                            firstOccurrence.timeInMillis = firstDayOfMonth.timeInMillis
                            firstOccurrence.add(Calendar.DAY_OF_MONTH, daysUntilWeekday)

                            // Add weeks to get to the desired occurrence
                            nextDate.timeInMillis = firstOccurrence.timeInMillis
                            nextDate.add(Calendar.DAY_OF_MONTH, 7 * (weekOfMonth - 1))

                            // If this pushes us into the next month, go back to the last occurrence in the target month
                            if (nextDate.get(Calendar.MONTH) != adjustedMonth) {
                                nextDate.add(Calendar.DAY_OF_MONTH, -7)
                            }

                            // If result is before or on start date, move to the next period
                            if (!nextDate.after(startDate)) {
                                val newTargetMonth = startDate.get(Calendar.MONTH) + value + 1
                                val newTargetYear = startDate.get(Calendar.YEAR) + newTargetMonth / 12
                                val newAdjustedMonth = newTargetMonth % 12

                                firstDayOfMonth.set(newTargetYear, newAdjustedMonth, 1)
                                val newFirstDayWeekday = firstDayOfMonth.get(Calendar.DAY_OF_WEEK)
                                var newDaysUntilWeekday = (targetWeekday - newFirstDayWeekday) % 7
                                if (newDaysUntilWeekday < 0) newDaysUntilWeekday += 7

                                firstOccurrence.timeInMillis = firstDayOfMonth.timeInMillis
                                firstOccurrence.add(Calendar.DAY_OF_MONTH, newDaysUntilWeekday)

                                nextDate.timeInMillis = firstOccurrence.timeInMillis
                                nextDate.add(Calendar.DAY_OF_MONTH, 7 * (weekOfMonth - 1))

                                if (nextDate.get(Calendar.MONTH) != newAdjustedMonth) {
                                    nextDate.add(Calendar.DAY_OF_MONTH, -7)
                                }
                            }
                        }

                        "dates" -> {
                            // Multiple specific dates in a month
                            val selectedDates = ArrayList<Int>()

                            if (customParams["selectedDates"] is List<*>) {
                                @Suppress("UNCHECKED_CAST")
                                val rawDates = customParams["selectedDates"] as List<*>
                                selectedDates.addAll(rawDates.mapNotNull {
                                    when (it) {
                                        is Int -> it
                                        is String -> it.toIntOrNull() ?: 1
                                        else -> 1
                                    }
                                })
                            } else {
                                selectedDates.add(startDate.get(Calendar.DAY_OF_MONTH))
                            }

                            if (selectedDates.isEmpty()) {
                                selectedDates.add(startDate.get(Calendar.DAY_OF_MONTH))
                            }

                            // Sort the dates
                            selectedDates.sort()

                            // Calculate target month and year
                            var targetMonth = startDate.get(Calendar.MONTH)
                            var targetYear = startDate.get(Calendar.YEAR)

                            // Find the next date in the current month
                            var nextDay = -1
                            for (day in selectedDates) {
                                if (day > startDate.get(Calendar.DAY_OF_MONTH)) {
                                    nextDay = day
                                    break
                                }
                            }

                            // If no valid date found in current month, move to future month
                            if (nextDay == -1) {
                                targetMonth += value
                                targetYear += targetMonth / 12
                                targetMonth %= 12
                                nextDay = selectedDates.first()
                            }

                            // Calculate next date
                            val maxDaysCalendar = Calendar.getInstance()
                            maxDaysCalendar.set(targetYear, targetMonth, 1)
                            val maxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                            nextDate.set(Calendar.YEAR, targetYear)
                            nextDate.set(Calendar.MONTH, targetMonth)
                            nextDate.set(Calendar.DAY_OF_MONTH, if (nextDay > maxDays) maxDays else nextDay)

                            // If result is before or on start date, move to the next period
                            if (!nextDate.after(startDate)) {
                                targetMonth = startDate.get(Calendar.MONTH) + value
                                targetYear = startDate.get(Calendar.YEAR) + targetMonth / 12
                                targetMonth %= 12

                                nextDay = selectedDates.first()
                                maxDaysCalendar.set(targetYear, targetMonth, 1)
                                val newMaxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                                nextDate.set(Calendar.YEAR, targetYear)
                                nextDate.set(Calendar.MONTH, targetMonth)
                                nextDate.set(Calendar.DAY_OF_MONTH, if (nextDay > newMaxDays) newMaxDays else nextDay)
                            }
                        }
                    }
                }

                "year" -> {
                    val yearlyOption = (customParams["yearlyOption"] as? String) ?: "day"
                    val selectedMonths = ArrayList<Boolean>()

                    if (customParams["selectedMonths"] is List<*>) {
                        @Suppress("UNCHECKED_CAST")
                        val rawMonths = customParams["selectedMonths"] as List<*>
                        selectedMonths.addAll(rawMonths.map { it == true })

                        // Ensure we have exactly 12 elements
                        if (selectedMonths.size < 12) {
                            repeat(12 - selectedMonths.size) { selectedMonths.add(false) }
                        } else if (selectedMonths.size > 12) {
                            selectedMonths.clear()
                            selectedMonths.addAll(selectedMonths.subList(0, 12))
                        }
                    } else {
                        selectedMonths.addAll(List(12) { false })
                    }

                    // Default to current month if none selected
                    if (!selectedMonths.contains(true)) {
                        selectedMonths[startDate.get(Calendar.MONTH)] = true
                    }

                    // Find the next month after current month
                    var nextMonth = -1
                    for (i in startDate.get(Calendar.MONTH) + 1 until 12) {
                        if (selectedMonths[i]) {
                            nextMonth = i
                            break
                        }
                    }

                    // Calculate target year
                    var targetYear = startDate.get(Calendar.YEAR)
                    if (nextMonth == -1) {
                        // If no months found after current month, go to next year
                        targetYear += value

                        // Find first selected month
                        for (i in 0 until 12) {
                            if (selectedMonths[i]) {
                                nextMonth = i
                                break
                            }
                        }
                    }

                    when (yearlyOption) {
                        "day" -> {
                            // Specific day of month (e.g., "January 15th")
                            val monthDay = customParams["monthDay"] as? Int ?: startDate.get(Calendar.DAY_OF_MONTH)

                            // Calculate next date
                            val maxDaysCalendar = Calendar.getInstance()
                            maxDaysCalendar.set(targetYear, nextMonth, 1)
                            val maxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                            nextDate.set(Calendar.YEAR, targetYear)
                            nextDate.set(Calendar.MONTH, nextMonth)
                            nextDate.set(Calendar.DAY_OF_MONTH, if (monthDay > maxDays) maxDays else monthDay)

                            // If this date is not after start date, add more years
                            if (!nextDate.after(startDate)) {
                                targetYear = startDate.get(Calendar.YEAR) + value
                                maxDaysCalendar.set(targetYear, nextMonth, 1)
                                val newMaxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

                                nextDate.set(Calendar.YEAR, targetYear)
                                nextDate.set(Calendar.MONTH, nextMonth)
                                nextDate.set(Calendar.DAY_OF_MONTH, if (monthDay > newMaxDays) newMaxDays else monthDay)
                            }
                        }

                        "weekday" -> {
                            // Specific weekday in month (e.g., "First Monday of January")
                            val weekOfYear = customParams["weekOfYear"] as? Int ?: 1
                            val dayOfWeekForYear = (customParams["dayOfWeekForYear"] as? String) ?: "Monday"

                            // Map dayOfWeek string to Calendar constant
                            val dayMap = mapOf(
                                "monday" to Calendar.MONDAY,
                                "mon" to Calendar.MONDAY,
                                "tuesday" to Calendar.TUESDAY,
                                "tue" to Calendar.TUESDAY,
                                "wednesday" to Calendar.WEDNESDAY,
                                "wed" to Calendar.WEDNESDAY,
                                "thursday" to Calendar.THURSDAY,
                                "thu" to Calendar.THURSDAY,
                                "friday" to Calendar.FRIDAY,
                                "fri" to Calendar.FRIDAY,
                                "saturday" to Calendar.SATURDAY,
                                "sat" to Calendar.SATURDAY,
                                "sunday" to Calendar.SUNDAY,
                                "sun" to Calendar.SUNDAY
                            )
                            val targetWeekday = dayMap[dayOfWeekForYear.toLowerCase(Locale.ROOT)] ?: Calendar.MONDAY

                            // Find the first occurrence of the weekday in the month
                            val firstDayOfMonth = Calendar.getInstance()
                            firstDayOfMonth.set(targetYear, nextMonth, 1)

                            val firstDayWeekday = firstDayOfMonth.get(Calendar.DAY_OF_WEEK)
                            var daysUntilWeekday = (targetWeekday - firstDayWeekday) % 7
                            if (daysUntilWeekday < 0) daysUntilWeekday += 7

                            val firstOccurrence = Calendar.getInstance()
                            firstOccurrence.timeInMillis = firstDayOfMonth.timeInMillis
                            firstOccurrence.add(Calendar.DAY_OF_MONTH, daysUntilWeekday)

                            // Add weeks to get to the desired occurrence
                            nextDate.timeInMillis = firstOccurrence.timeInMillis
                            nextDate.add(Calendar.DAY_OF_MONTH, 7 * (weekOfYear - 1))

                            // If this pushes us into the next month, go back to the last occurrence
                            if (nextDate.get(Calendar.MONTH) != nextMonth) {
                                nextDate.add(Calendar.DAY_OF_MONTH, -7)
                            }

                            // If not after start date, go to next occurrence in future year
                            if (!nextDate.after(startDate)) {
                                targetYear = startDate.get(Calendar.YEAR) + value

                                firstDayOfMonth.set(targetYear, nextMonth, 1)
                                val newFirstDayWeekday = firstDayOfMonth.get(Calendar.DAY_OF_WEEK)
                                var newDaysUntilWeekday = (targetWeekday - newFirstDayWeekday) % 7
                                if (newDaysUntilWeekday < 0) newDaysUntilWeekday += 7

                                firstOccurrence.timeInMillis = firstDayOfMonth.timeInMillis
                                firstOccurrence.add(Calendar.DAY_OF_MONTH, newDaysUntilWeekday)

                                nextDate.timeInMillis = firstOccurrence.timeInMillis
                                nextDate.add(Calendar.DAY_OF_MONTH, 7 * (weekOfYear - 1))

                                if (nextDate.get(Calendar.MONTH) != nextMonth) {
                                    nextDate.add(Calendar.DAY_OF_MONTH, -7)
                                }
                            }
                        }
                    }
                }
            }

            // Final safety check to ensure the next date is after the start date
            if (!nextDate.after(startDate)) {
                // If still not after start date, add one more frequency unit
                when (frequencyType) {
                    "day" -> {
                        nextDate.timeInMillis = startDate.timeInMillis
                        nextDate.add(Calendar.DAY_OF_MONTH, value)
                    }
                    "week" -> {
                        nextDate.timeInMillis = startDate.timeInMillis
                        nextDate.add(Calendar.DAY_OF_MONTH, 7 * value)
                    }
                    "month" -> {
                        // Handle month overflow correctly
                        val targetMonth = startDate.get(Calendar.MONTH) + value
                        val targetYear = startDate.get(Calendar.YEAR) + targetMonth / 12
                        val adjustedMonth = targetMonth % 12

                        val maxDaysCalendar = Calendar.getInstance()
                        maxDaysCalendar.set(targetYear, adjustedMonth, 1)
                        val maxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)
                        val day = if (startDate.get(Calendar.DAY_OF_MONTH) > maxDays) maxDays else startDate.get(Calendar.DAY_OF_MONTH)

                        nextDate.set(targetYear, adjustedMonth, day)
                    }
                    "year" -> {
                        val targetYear = startDate.get(Calendar.YEAR) + value
                        val month = startDate.get(Calendar.MONTH)

                        val maxDaysCalendar = Calendar.getInstance()
                        maxDaysCalendar.set(targetYear, month, 1)
                        val maxDays = maxDaysCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)
                        val day = if (startDate.get(Calendar.DAY_OF_MONTH) > maxDays) maxDays else startDate.get(Calendar.DAY_OF_MONTH)

                        nextDate.set(targetYear, month, day)
                    }
                }
            }

            return nextDate
        }
    }
}