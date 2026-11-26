//
//  ChartViews.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI

/// Lightweight doughnut chart rendering status-count segments.
struct DoughnutChartCard: View {
    let segments: [(status: ResultStatus, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Distribution")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 20) {
                DoughnutChart(segments: segments)
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(segments, id: \.status) { seg in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(seg.status.chartColor)
                                .frame(width: 10, height: 10)
                            Text(seg.status.label)
                                .font(.caption)
                            Spacer()
                            Text("\(seg.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground),
                    in: .rect(cornerRadius: 14))
    }
}

private struct DoughnutChart: View {
    let segments: [(status: ResultStatus, count: Int)]

    private var total: Int {
        segments.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        Canvas { context, size in
            guard total > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let innerRadius = radius * 0.6

            var startAngle = Angle.degrees(-90)
            for seg in segments {
                let fraction = Double(seg.count) / Double(total)
                let endAngle = startAngle + .degrees(360 * fraction)
                let path = Path { p in
                    p.move(to: center)
                    p.addArc(center: center, radius: radius,
                              startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    p.addArc(center: center, radius: innerRadius,
                              startAngle: endAngle, endAngle: startAngle, clockwise: true)
                    p.closeSubpath()
                }
                context.fill(path, with: .color(seg.status.chartColor))
                startAngle = endAngle
            }
        }
    }
}

/// Lightweight line chart for success-rate trend.
struct LineChartCard: View {
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Success Rate Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Last \(values.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LineChart(values: values)
                .frame(height: 100)

            HStack {
                Text("0%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("100%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground),
                    in: .rect(cornerRadius: 14))
    }
}

private struct LineChart: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                if let single = values.first {
                    drawPoint(at: CGPoint(x: size.width / 2, y: size.height * (1 - CGFloat(single / 100))),
                              context: context)
                }
                return
            }

            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height * (1 - CGFloat(value / 100))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 2.5)

            // Gradient fill under the line
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(.accentColor.opacity(0.15)))

            // Dots
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height * (1 - CGFloat(value / 100))
                drawPoint(at: CGPoint(x: x, y: y), context: context)
            }
        }
    }

    private func drawPoint(at point: CGPoint, context: GraphicsContext) {
        let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: rect), with: .color(.accentColor))
    }
}

// MARK: - Status Color Extension

extension ResultStatus {
    /// Chart color for each status category.
    var chartColor: Color {
        switch self {
        case .resultsFound: .green
        case .paymentError: .red
        case .unknown: .orange
        case .noResults: .gray
        }
    }

    /// Badge color (same as chartColor, but could differ).
    var badgeColor: Color { chartColor }
}

#Preview {
    VStack {
        DoughnutChartCard(segments: [
            (.resultsFound, 30), (.paymentError, 5), (.unknown, 3), (.noResults, 2)
        ])
        LineChartCard(values: [60, 70, 65, 80, 75, 85, 90])
    }
    .padding()
    .environment(\.colorScheme, .dark)
}
