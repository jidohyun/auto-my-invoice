import SwiftUI

/// AMI parity (iOS): read-only analytics screen mirroring the web dashboard's
/// charts — monthly collections, status distribution, invoice aging, reminder
/// effectiveness, and the client payment ranking. Money is server-rolled to KRW
/// (AMI-90), so all amounts render with the KRW formatter.
struct AnalyticsView: View {
    @State private var vm = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if vm.isLoading && vm.analytics == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if let error = vm.error, vm.analytics == nil {
                        ErrorStateView(message: error) { Task { await vm.load() } }
                            .padding(.top, 40)
                    } else {
                        if let a = vm.analytics {
                            monthlySection(a.monthlyCollections)
                            statusSection(a.statusDistribution)
                            agingSection(a.invoiceAging)
                        }
                        if let r = vm.reminders { reminderSection(r) }
                        if !vm.ranking.isEmpty { rankingSection(vm.ranking) }
                    }
                }
                .padding(16)
            }
            .navigationTitle("분석")
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
    }

    // MARK: - Monthly collections (bar chart)

    private func monthlySection(_ rows: [MonthlyCollectionDTO]) -> some View {
        let maxValue = rows
            .compactMap { Double($0.invoiced) }
            .max() ?? 1

        return section("월별 청구·수금") {
            if rows.isEmpty {
                emptyHint("데이터가 없습니다.")
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        MonthlyBar(row: row, maxValue: maxValue == 0 ? 1 : maxValue)
                    }
                }
            }
        }
    }

    // MARK: - Status distribution

    private func statusSection(_ rows: [StatusDistributionDTO]) -> some View {
        section("상태 분포") {
            if rows.isEmpty {
                emptyHint("데이터가 없습니다.")
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack {
                            StatusBadge(status: row.status)
                            Spacer()
                            Text("\(row.count)건").font(.subheadline)
                            Text(MoneyFormatter.format(row.total, currency: "KRW"))
                                .font(AppFont.money(15)).foregroundStyle(AppColor.baseContent.opacity(0.6))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Invoice aging

    private func agingSection(_ buckets: [String: AgingBucketDTO]) -> some View {
        // Fixed display order so the buckets always read youngest → oldest.
        let order = ["0-30", "31-60", "61-90", "90+"]
        return section("미수금 연령") {
            VStack(spacing: 8) {
                ForEach(order, id: \.self) { key in
                    let bucket = buckets[key]
                    HStack {
                        Text("\(key)일").font(.subheadline)
                        Spacer()
                        Text("\(bucket?.count ?? 0)건").font(.subheadline)
                        Text(MoneyFormatter.format(bucket?.total ?? "0", currency: "KRW"))
                            .font(AppFont.money(15)).foregroundStyle(AppColor.baseContent.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Reminder effectiveness

    private func reminderSection(_ r: ReminderEffectivenessDTO) -> some View {
        section("리마인더 효과") {
            VStack(spacing: 8) {
                statRow("발송", "\(r.totalSent)건")
                statRow("열람률", String(format: "%.1f%%", r.overallOpenRate))
                statRow("클릭률", String(format: "%.1f%%", r.overallClickRate))
                if let conv = r.overallConversionRate {
                    statRow("결제 전환율", String(format: "%.1f%%", conv))
                }
                // avg_days_to_payment is a per-step array; collapse to a
                // sample-weighted overall average for a single figure.
                if let days = weightedAvgDays(r.avgDaysToPayment) {
                    statRow("평균 결제 소요", String(format: "%.1f일", days))
                }
            }
        }
    }

    /// Sample-weighted mean of per-step avg-days rows; nil when there is no data.
    private func weightedAvgDays(_ rows: [AvgDaysToPaymentEntryDTO]) -> Double? {
        let totalSamples = rows.reduce(0) { $0 + $1.sampleSize }
        guard totalSamples > 0 else { return nil }
        let weighted = rows.reduce(0.0) { $0 + $1.avgDays * Double($1.sampleSize) }
        return weighted / Double(totalSamples)
    }

    // MARK: - Client ranking

    private func rankingSection(_ rows: [ClientRankingDTO]) -> some View {
        section("고객 결제 순위") {
            VStack(spacing: 10) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.name).font(.body.weight(.medium))
                            Spacer()
                            if let days = row.avgPaymentDays {
                                Text(String(format: "평균 %.0f일", days))
                                    .font(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
                            }
                        }
                        HStack {
                            Text("청구 \(MoneyFormatter.format(row.totalInvoiced, currency: "KRW"))")
                                .font(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
                            Spacer()
                            if let rate = row.onTimeRate {
                                Text(String(format: "정시 %.0f%%", rate))
                                    .font(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
                            }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: - Building blocks

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).appFont(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCard()
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(AppColor.baseContent.opacity(0.6))
            Spacer()
            Text(value).font(.subheadline.weight(.medium))
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
    }
}

/// One row of the monthly collections bar chart. Two stacked bars (invoiced vs
/// collected) sized relative to the period's max invoiced amount.
private struct MonthlyBar: View {
    let row: MonthlyCollectionDTO
    let maxValue: Double

    var body: some View {
        let invoiced = Double(row.invoiced) ?? 0
        let collected = Double(row.collected) ?? 0

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.month).font(.caption.weight(.medium))
                Spacer()
                Text(MoneyFormatter.format(row.collected, currency: "KRW"))
                    .font(AppFont.money(11)).foregroundStyle(AppColor.baseContent.opacity(0.6))
            }
            bar(value: invoiced, color: AppColor.base300)
            bar(value: collected, color: AppColor.primary)
        }
    }

    private func bar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            let fraction = maxValue > 0 ? value / maxValue : 0
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: max(2, geo.size.width * fraction))
        }
        .frame(height: 8)
    }
}
