import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/analysis.dart';
import '../../../../core/theme/app_theme.dart';

class AnalysisRadarChart extends StatelessWidget {
  final Analysis analysis;

  const AnalysisRadarChart({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Dimension Scores
    // Culture: Elements 1, 2
    double cultureSum = (analysis.supportiveEnvironmentScore ?? 0) + 
                        (analysis.positiveExpectationsScore ?? 0).toDouble();
    double cultureAvg = cultureSum / 2;

    // Instruction: Elements 3, 4, 5, 6
    double instructSum = (analysis.lessonFacilitationScore ?? 0) +
                         (analysis.checksUnderstandingScore ?? 0) +
                         (analysis.feedbackScore ?? 0) +
                         (analysis.criticalThinkingScore ?? 0).toDouble();
    double instructAvg = instructSum / 4;

    // Socioemotional: Elements 7, 8, 9
    double selSum = (analysis.autonomyScore ?? 0) +
                    (analysis.perseveranceScore ?? 0) +
                    (analysis.socialCollaborativeScore ?? 0).toDouble();
    double selAvg = selSum / 3;

    // Define data entries
    final dataEntries = [
      RadarEntry(value: cultureAvg),
      RadarEntry(value: instructAvg),
      RadarEntry(value: selAvg),
    ];

    return SizedBox(
      height: 360, // Increased height for better spacing
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Chart with padding to make room for labels
          Padding(
            padding: const EdgeInsets.only(top: 50.0, bottom: 20.0, left: 20.0, right: 20.0),
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: AppTheme.primaryColor.withOpacity(0.4),
                    borderColor: AppTheme.primaryColor,
                    entryRadius: 4,
                    dataEntries: dataEntries,
                    borderWidth: 3,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
                tickCount: 5,
                ticksTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                tickBorderData: const BorderSide(color: Colors.white24, width: 0.5),
                gridBorderData: const BorderSide(color: Colors.white24, width: 0.5),
                
                getTitle: (index, angle) {
                  return const RadarChartTitle(text: '');
                },
              ),
              swapAnimationDuration: const Duration(milliseconds: 150),
              swapAnimationCurve: Curves.linear,
            ),
          ),
          
          // Custom Labels
          // Classroom Culture (Top - Index 0)
          Align(
            alignment: const Alignment(0, -1.0), // Pin to top
            child: Text(
              'Classroom\nCulture',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryColor, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          
          // Instruction (Bottom Right - Index 1)
          Align(
            alignment: const Alignment(0.8, 0.75), 
            child: Text(
              'Instruction',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryColor, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          
          // Socioemotional Skills (Bottom Left - Index 2)
          Align(
            alignment: const Alignment(-0.8, 0.75), 
            child: Text(
              'Socioemotional\nSkills',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.warningColor, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
