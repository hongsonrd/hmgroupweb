import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

class ChartData {
  final String chartType;
  final String title;
  final String unitY;
  final String xLabel;
  final String yLabel;
  final List<FlSpot> spots;
  final List<String> xAxisLabels;
  final ChartOptions chartOptions;
  final AxisLimits axisLimits;

  ChartData({
    required this.chartType,
    required this.title,
    required this.unitY,
    required this.xLabel,
    required this.yLabel,
    required this.spots,
    required this.xAxisLabels,
    required this.chartOptions,
    required this.axisLimits,
  });

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      chartType: json['chartType'] ?? 'line',
      title: json['title'] ?? '',
      unitY: json['unitY'] ?? '',
      xLabel: json['xLabel'] ?? '',
      yLabel: json['yLabel'] ?? '',
      spots: (json['spots'] as List?)
              ?.map((s) => FlSpot(
                    (s['x'] as num).toDouble(),
                    (s['y'] as num).toDouble(),
                  ))
              .toList() ??
          [],
      xAxisLabels: (json['xAxisLabels'] as List?)?.map((e) => e.toString()).toList() ?? [],
      chartOptions: ChartOptions.fromJson(json['chartOptions'] ?? {}),
      axisLimits: AxisLimits.fromJson(json['axisLimits'] ?? {}),
    );
  }
}

class ChartOptions {
  final bool isCurved;
  final Color lineColor;
  final double lineWidth;
  final bool showAreaUnderLine;
  final Color areaColor;

  ChartOptions({
    required this.isCurved,
    required this.lineColor,
    required this.lineWidth,
    required this.showAreaUnderLine,
    required this.areaColor,
  });

  factory ChartOptions.fromJson(Map<String, dynamic> json) {
    return ChartOptions(
      isCurved: json['isCurved'] ?? true,
      lineColor: _parseColor(json['lineColor'] ?? '#007BFF'),
      lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 2.0,
      showAreaUnderLine: json['showAreaUnderLine'] ?? true,
      areaColor: _parseColor(json['areaColor'] ?? '#007BFF80'),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class AxisLimits {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  AxisLimits({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory AxisLimits.fromJson(Map<String, dynamic> json) {
    return AxisLimits(
      minX: (json['minX'] as num?)?.toDouble() ?? 0,
      maxX: (json['maxX'] as num?)?.toDouble() ?? 10,
      minY: (json['minY'] as num?)?.toDouble() ?? 0,
      maxY: (json['maxY'] as num?)?.toDouble() ?? 100,
    );
  }
}

ChartData? extractChartFromText(String text) {
  final jsonPattern = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', multiLine: true);
  final match = jsonPattern.firstMatch(text);
  if (match != null) {
    try {
      final jsonStr = match.group(1)!;
      final cleanJson = jsonStr.replaceAll(RegExp(r'//.*'), '');
      final data = json.decode(cleanJson);
      if (data['chartType'] != null) {
        return ChartData.fromJson(data);
      }
    } catch (e) {
      print('Chart parse error: $e');
    }
  }
  return null;
}

class ChartThumbnail extends StatelessWidget {
  final ChartData chartData;
  final VoidCallback onTap;

  const ChartThumbnail({
    Key? key,
    required this.chartData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chartData.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.open_in_full, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: chartData.axisLimits.minX,
                  maxX: chartData.axisLimits.maxX,
                  minY: chartData.axisLimits.minY,
                  maxY: chartData.axisLimits.maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData.spots,
                      isCurved: chartData.chartOptions.isCurved,
                      color: chartData.chartOptions.lineColor,
                      barWidth: chartData.chartOptions.lineWidth,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: chartData.chartOptions.showAreaUnderLine,
                        color: chartData.chartOptions.areaColor,
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartPopup extends StatelessWidget {
  final ChartData chartData;

  const ChartPopup({Key? key, required this.chartData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    chartData.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (chartData.axisLimits.maxY - chartData.axisLimits.minY) / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < chartData.xAxisLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                chartData.xAxisLabels[index],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: (chartData.axisLimits.maxY - chartData.axisLimits.minY) / 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatNumber(value),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: chartData.axisLimits.minX,
                  maxX: chartData.axisLimits.maxX,
                  minY: chartData.axisLimits.minY,
                  maxY: chartData.axisLimits.maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData.spots,
                      isCurved: chartData.chartOptions.isCurved,
                      color: chartData.chartOptions.lineColor,
                      barWidth: chartData.chartOptions.lineWidth,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: chartData.chartOptions.lineColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: chartData.chartOptions.showAreaUnderLine,
                        color: chartData.chartOptions.areaColor,
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final xIndex = spot.x.toInt();
                          final xLabel = xIndex >= 0 && xIndex < chartData.xAxisLabels.length
                              ? chartData.xAxisLabels[xIndex]
                              : '';
                          return LineTooltipItem(
                            '$xLabel\n${_formatNumber(spot.y)} ${chartData.unitY}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}