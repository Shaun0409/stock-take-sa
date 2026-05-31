// backend/src/calculations/metrics.js
// Complete calculation engine for all store metrics

class MetricsCalculator {
    constructor(db) {
        this.db = db;
    }

    /**
     * Calculate all metrics for a store between two stock takes
     * @param {UUID} storeId 
     * @param {Date} startDate 
     * @param {Date} endDate 
     * @returns {Object} Complete metrics
     */
    async calculateAllMetrics(storeId, startDate, endDate) {
        // Get opening stock take
        const openingStockTake = await this.getStockTakeAtDate(storeId, startDate);
        // Get closing stock take
        const closingStockTake = await this.getStockTakeAtDate(storeId, endDate);
        
        // Get sales data for period
        const salesData = await this.getSalesData(storeId, startDate, endDate);
        
        // Get purchases for period
        const purchases = await this.getPurchases(storeId, startDate, endDate);
        
        // Get adjustments (shrinkage, spoilage, etc.)
        const adjustments = await this.getAdjustments(storeId, startDate, endDate);

        // Calculate all metrics
        const stockMetrics = this.calculateStockMetrics(openingStockTake, closingStockTake);
        const profitMetrics = this.calculateProfitMetrics(stockMetrics, salesData, purchases);
        const shrinkageMetrics = this.calculateShrinkageMetrics(stockMetrics, salesData, purchases, adjustments);
        const turnoverMetrics = this.calculateTurnoverMetrics(stockMetrics, salesData);
        const salesMetrics = this.calculateSalesMetrics(salesData);
        const vatMetrics = this.calculateVATMetrics(salesData, purchases);
        
        return {
            period: { startDate, endDate },
            stock: stockMetrics,
            profit: profitMetrics,
            shrinkage: shrinkageMetrics,
            turnover: turnoverMetrics,
            sales: salesMetrics,
            vat: vatMetrics,
            timestamp: new Date()
        };
    }

    /**
     * Stock metrics (Category 1)
     */
    calculateStockMetrics(openingStock, closingStock) {
        const openingValue = this.sumStockValues(openingStock);
        const closingValue = this.sumStockValues(closingStock);
        const avgInventory = (openingValue + closingValue) / 2;
        
        return {
            opening_stock_value: openingValue,
            closing_stock_value: closingValue,
            avg_inventory_value: avgInventory,
            opening_stock_by_category: this.groupByCategory(openingStock),
            closing_stock_by_category: this.groupByCategory(closingStock),
            stock_variance: closingValue - openingValue
        };
    }

    /**
     * Profit metrics (Category 2)
     */
    calculateProfitMetrics(stockMetrics, salesData, purchases) {
        const opening = stockMetrics.opening_stock_value;
        const closing = stockMetrics.closing_stock_value;
        const purchaseValue = this.sumPurchaseValues(purchases);
        
        // Theoretical COGS = Opening + Purchases - Closing
        const theoreticalCOGS = opening + purchaseValue - closing;
        
        // Actual COGS from sales data
        const actualCOGS = salesData.total_sales_cost || (salesData.total_revenue * 0.75); // Estimate if not available
        
        const grossProfit = salesData.total_revenue - actualCOGS;
        const grossProfitPercentage = (grossProfit / salesData.total_revenue) * 100;
        
        return {
            theoretical_cogs: theoreticalCOGS,
            actual_cogs: actualCOGS,
            gross_profit_rand: grossProfit,
            gross_profit_percentage: grossProfitPercentage,
            net_profit: grossProfit - (purchases.vat_amount || 0), // Simplified
            return_on_inventory: grossProfit / stockMetrics.avg_inventory_value
        };
    }

    /**
     * Shrinkage metrics (Category 3)
     */
    calculateShrinkageMetrics(stockMetrics, salesData, purchases, adjustments) {
        const opening = stockMetrics.opening_stock_value;
        const closing = stockMetrics.closing_stock_value;
        const purchaseValue = this.sumPurchaseValues(purchases);
        
        // Theoretical sales (what should have sold)
        const theoreticalSalesValue = opening + purchaseValue - closing;
        
        // Actual sales (what did sell)
        const actualSalesValue = salesData.total_sales_revenue || 0;
        
        // Shrinkage in Rands
        const shrinkageValue = theoreticalSalesValue - actualSalesValue;
        const shrinkagePercentage = theoreticalSalesValue > 0 
            ? (shrinkageValue / theoreticalSalesValue) * 100 
            : 0;
        
        // Breakdown by adjustment type
        const shrinkageByType = this.groupAdjustmentsByType(adjustments);
        
        return {
            total_shrinkage_rand: shrinkageValue,
            total_shrinkage_percentage: shrinkagePercentage,
            target_met: shrinkagePercentage <= 2.0, // Target < 2%
            by_type: shrinkageByType,
            by_product: this.topShrinkageProducts(adjustments),
            by_category: this.shrinkageByCategory(adjustments),
            theoretical_sales_value: theoreticalSalesValue,
            actual_sales_value: actualSalesValue
        };
    }

    /**
     * Turnover metrics (Category 4)
     */
    calculateTurnoverMetrics(stockMetrics, salesData) {
        const cogs = salesData.total_sales_cost || 0;
        const avgInventory = stockMetrics.avg_inventory_value;
        
        const turnoverRate = avgInventory > 0 ? cogs / avgInventory : 0;
        const daysInventory = turnoverRate > 0 ? 365 / turnoverRate : 0;
        
        // Identify slow and fast movers
        const productVelocity = this.calculateProductVelocity(salesData);
        
        return {
            stock_turnover_rate: turnoverRate,
            days_inventory_on_hand: daysInventory,
            fast_movers: productVelocity.filter(p => p.velocity_percentile >= 80),
            slow_movers: productVelocity.filter(p => p.velocity_percentile <= 20),
            dead_stock: productVelocity.filter(p => p.units_sold === 0 && p.days_without_sale > 60)
        };
    }

    /**
     * Sales metrics (Category 5)
     */
    calculateSalesMetrics(salesData) {
        const avgTransactionValue = salesData.total_transactions > 0 
            ? salesData.total_revenue / salesData.total_transactions 
            : 0;
        
        return {
            total_sales_rand: salesData.total_revenue,
            total_transactions: salesData.total_transactions,
            average_transaction_value: avgTransactionValue,
            sales_by_day: salesData.by_day,
            sales_by_hour: salesData.by_hour,
            sales_by_payment_type: salesData.payment_breakdown,
            top_products: salesData.top_products,
            bottom_products: salesData.bottom_products,
            month_on_month_growth: salesData.mom_growth,
            year_on_year_growth: salesData.yoy_growth
        };
    }

    /**
     * VAT & Tax metrics (Category 8 - SA specific)
     */
    calculateVATMetrics(salesData, purchases) {
        const standardRateSales = salesData.standard_rate_revenue || 0;
        const zeroRateSales = salesData.zero_rate_revenue || 0;
        
        const outputVAT = standardRateSales * 0.15; // 15% VAT
        const inputVAT = purchases.total_vat || 0;
        const vatPayable = outputVAT - inputVAT;
        
        return {
            output_vat: outputVAT,
            input_vat: inputVAT,
            vat_payable_to_sars: vatPayable,
            zero_rated_sales: zeroRateSales,
            standard_rate_sales: standardRateSales,
            estimated_provisional_tax: (salesData.total_revenue - purchases.total_amount) * 0.28, // 28% corporate tax
            turnover_tax_eligible: salesData.total_revenue < 1000000 // R1M threshold
        };
    }

    // =====================================================
    // Helper methods (database queries)
    // =====================================================

    async getStockTakeAtDate(storeId, date) {
        const query = `
            SELECT sti.*, p.name, p.category
            FROM stock_take_items sti
            JOIN stock_takes st ON sti.stock_take_id = st.id
            JOIN products p ON sti.product_id = p.id
            WHERE st.store_id = $1 
            AND st.stock_take_date <= $2
            AND st.status = 'completed'
            ORDER BY st.stock_take_date DESC
            LIMIT 1
        `;
        const result = await this.db.query(query, [storeId, date]);
        return result.rows;
    }

    async getSalesData(storeId, startDate, endDate) {
        const query = `
            SELECT 
                SUM(total_sales_revenue) as total_revenue,
                SUM(total_transactions) as total_transactions,
                AVG(total_sales_revenue / NULLIF(total_transactions, 0)) as avg_transaction_value
            FROM sales_periods
            WHERE store_id = $1 
            AND start_date >= $2 
            AND end_date <= $3
        `;
        const result = await this.db.query(query, [storeId, startDate, endDate]);
        return result.rows[0] || { total_revenue: 0, total_transactions: 0 };
    }

    async getPurchases(storeId, startDate, endDate) {
        const query = `
            SELECT 
                SUM(total_amount) as total_amount,
                SUM(vat_amount) as total_vat
            FROM purchases
            WHERE store_id = $1 
            AND purchase_date BETWEEN $2 AND $3
        `;
        const result = await this.db.query(query, [storeId, startDate, endDate]);
        return result.rows[0] || { total_amount: 0, total_vat: 0 };
    }

    async getAdjustments(storeId, startDate, endDate) {
        const query = `
            SELECT a.*, at.name as adjustment_type_name, p.name as product_name, p.category
            FROM adjustments a
            JOIN adjustment_types at ON a.adjustment_type_id = at.id
            JOIN products p ON a.product_id = p.id
            WHERE a.store_id = $1 
            AND a.adjustment_date BETWEEN $2 AND $3
        `;
        const result = await this.db.query(query, [storeId, startDate, endDate]);
        return result.rows;
    }

    sumStockValues(stockItems) {
        return stockItems.reduce((sum, item) => sum + (item.counted_quantity * item.cost_price_at_time), 0);
    }

    sumPurchaseValues(purchases) {
        return purchases.total_amount || 0;
    }

    groupByCategory(stockItems) {
        const categories = {};
        for (const item of stockItems) {
            const value = item.counted_quantity * item.cost_price_at_time;
            categories[item.category] = (categories[item.category] || 0) + value;
        }
        return categories;
    }

    groupAdjustmentsByType(adjustments) {
        const types = {};
        for (const adj of adjustments) {
            types[adj.adjustment_type_name] = (types[adj.adjustment_type_name] || 0) + (adj.quantity * adj.value_at_time);
        }
        return types;
    }

    topShrinkageProducts(adjustments, limit = 10) {
        const productMap = new Map();
        for (const adj of adjustments) {
            const value = adj.quantity * adj.value_at_time;
            productMap.set(adj.product_name, (productMap.get(adj.product_name) || 0) + value);
        }
        
        return Array.from(productMap.entries())
            .map(([product, value]) => ({ product, shrinkage_value: value }))
            .sort((a, b) => b.shrinkage_value - a.shrinkage_value)
            .slice(0, limit);
    }

    shrinkageByCategory(adjustments) {
        const categories = {};
        for (const adj of adjustments) {
            const value = adj.quantity * adj.value_at_time;
            categories[adj.category] = (categories[adj.category] || 0) + value;
        }
        return categories;
    }

    calculateProductVelocity(salesData) {
        // Placeholder - would need detailed sales data
        return [];
    }
}

module.exports = MetricsCalculator;