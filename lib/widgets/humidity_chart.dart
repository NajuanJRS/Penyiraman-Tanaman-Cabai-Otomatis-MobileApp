import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/perkembangan.dart';
import '../models/chart_data.dart';
import '../theme/app_colors.dart';

class HumidityChart extends StatelessWidget {
  final List<Perkembangan> data;

  final String filter;
  const HumidityChart({super.key, required this.data, required this.filter});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    DateTime startDate;

    switch (filter) {
      case "1 Hari":
        startDate = now.subtract(const Duration(days: 1));
        break;

      case "3 Hari":
        startDate = now.subtract(const Duration(days: 3));
        break;

      case "1 Minggu":
        startDate = now.subtract(const Duration(days: 7));
        break;

      case "2 Minggu":
        startDate = now.subtract(const Duration(days: 14));
        break;

      case "3 Minggu":
        startDate = now.subtract(const Duration(days: 21));
        break;

      default:
        startDate = DateTime(now.year, now.month - 1, now.day);
    }

    final chartData =
        data.where((item) {
          final waktu = DateTime.parse(item.waktu);

          return waktu.isAfter(startDate);
        }).toList();
    final tanahData =
        chartData.map((e) {
          return ChartData(DateTime.parse(e.waktu), e.kelembapanTanah);
        }).toList();

    final udaraData =
        chartData.map((e) {
          return ChartData(DateTime.parse(e.waktu), e.kelembapanUdara);
        }).toList();

    if (chartData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),

          child: Center(
            child: Text("Tidak ada data chart pada rentang waktu ini"),
          ),
        ),
      );
    }

    final latestDate = DateTime.parse(chartData.last.waktu);

    final monthYear = DateFormat('MMMM yyyy', 'id_ID').format(latestDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kelembapan Tanah & Udara",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),

            const SizedBox(height: 5),

            Text(monthYear, style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            SizedBox(
              height: 350,

              child: SfCartesianChart(
                onTrackballPositionChanging: (TrackballArgs args) {
                  final index = args.chartPointInfo.dataPointIndex;

                  if (index == null) return;

                  final date = tanahData[index].waktu;

                  args.chartPointInfo.header = DateFormat(
                    'dd MMM yyyy, HH:mm:ss',
                    'id_ID',
                  ).format(date);
                },

                title: ChartTitle(text: 'Grafik Kelembapan - $monthYear'),

                legend: Legend(isVisible: true, position: LegendPosition.top),

                trackballBehavior: TrackballBehavior(
                  enable: true,
                  activationMode: ActivationMode.singleTap,
                  tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                  lineType: TrackballLineType.vertical,
                  tooltipSettings: const InteractiveTooltip(enable: true),
                ),

                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.days,

                  dateFormat: DateFormat('dd'),

                  title: AxisTitle(text: 'Tanggal'),
                ),

                primaryYAxis: NumericAxis(
                  minimum: 0,
                  maximum: 100,

                  title: AxisTitle(text: 'Persentase (%)'),
                ),

                series: <CartesianSeries>[
                  SplineSeries<ChartData, DateTime>(
                    name: 'Kelembapan Tanah (%)',
                    color: AppColors.soilBrown,
                    enableTooltip: true,
                    dataSource: tanahData,
                    xValueMapper: (data, _) => data.waktu,
                    yValueMapper: (data, _) => data.nilai,
                    markerSettings: const MarkerSettings(isVisible: false),
                  ),

                  SplineSeries<ChartData, DateTime>(
                    name: 'Kelembapan Udara (%)',
                    color: AppColors.waterBlue,
                    enableTooltip: true,
                    dataSource: udaraData,
                    xValueMapper: (data, _) => data.waktu,
                    yValueMapper: (data, _) => data.nilai,
                    markerSettings: const MarkerSettings(isVisible: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
