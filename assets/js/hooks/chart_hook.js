const ChartHook = {
  mounted() {
    this.chart = null
    this.renderChart()
    this.handleEvent("chart-data", ({data, type, options}) => {
      this.updateChart(data, type, options)
    })
  },

  renderChart() {
    const canvas = this.el.querySelector("canvas") || this.el
    const chartData = JSON.parse(this.el.dataset.chartData || "{}")
    const chartType = this.el.dataset.chartType || "bar"
    const chartOptions = JSON.parse(this.el.dataset.chartOptions || "{}")

    if (!chartData.labels && !chartData.datasets) return

    if (this.chart) this.chart.destroy()

    this.chart = new Chart(canvas, {
      type: chartType,
      data: chartData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        ...chartOptions
      }
    })
  },

  updateChart(data, type, options) {
    if (this.chart) this.chart.destroy()
    const canvas = this.el.querySelector("canvas") || this.el
    this.chart = new Chart(canvas, {
      type: type || "bar",
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        ...(options || {})
      }
    })
  },

  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

export default ChartHook
