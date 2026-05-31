// backend/src/api/routes/metrics.js
const express = require('express');
const router = express.Router();
const MetricsCalculator = require('../../calculations/metrics');
const db = require('../../db/connection');

const calculator = new MetricsCalculator(db);

// Get all metrics for a store
router.get('/stores/:storeId/metrics', async (req, res) => {
    try {
        const { storeId } = req.params;
        const { start_date, end_date } = req.query;
        
        if (!start_date || !end_date) {
            return res.status(400).json({ error: 'start_date and end_date are required' });
        }
        
        const metrics = await calculator.calculateAllMetrics(
            storeId, 
            new Date(start_date), 
            new Date(end_date)
        );
        
        res.json(metrics);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to calculate metrics' });
    }
});

// Get specific metric category
router.get('/stores/:storeId/metrics/:category', async (req, res) => {
    try {
        const { storeId, category } = req.params;
        const { start_date, end_date } = req.query;
        
        const allMetrics = await calculator.calculateAllMetrics(
            storeId, 
            new Date(start_date), 
            new Date(end_date)
        );
        
        const allowedCategories = ['stock', 'profit', 'shrinkage', 'turnover', 'sales', 'vat'];
        
        if (!allowedCategories.includes(category)) {
            return res.status(400).json({ error: 'Invalid category' });
        }
        
        res.json({ [category]: allMetrics[category] });
    } catch (error) {
        res.status(500).json({ error: 'Failed to calculate metrics' });
    }
});

// Get shrinkage report (most requested)
router.get('/stores/:storeId/shrinkage-report', async (req, res) => {
    try {
        const { storeId } = req.params;
        const { start_date, end_date } = req.query;
        
        const metrics = await calculator.calculateAllMetrics(
            storeId, 
            new Date(start_date), 
            new Date(end_date)
        );
        
        const report = {
            store_id: storeId,
            period: metrics.period,
            shrinkage_percentage: metrics.shrinkage.total_shrinkage_percentage,
            shrinkage_rand: metrics.shrinkage.total_shrinkage_rand,
            target_met: metrics.shrinkage.target_met,
            breakdown: metrics.shrinkage.by_type,
            top_items: metrics.shrinkage.by_product,
            recommendations: generateShrinkageRecommendations(metrics.shrinkage)
        };
        
        res.json(report);
    } catch (error) {
        res.status(500).json({ error: 'Failed to generate shrinkage report' });
    }
});

// Helper function
function generateShrinkageRecommendations(shrinkageMetrics) {
    const recommendations = [];
    
    if (shrinkageMetrics.total_shrinkage_percentage > 5) {
        recommendations.push('CRITICAL: Shrinkage exceeds 5% - immediate security audit recommended');
    } else if (shrinkageMetrics.total_shrinkage_percentage > 2) {
        recommendations.push('WARNING: Shrinkage above 2% target - review theft hotspots and staff training');
    }
    
    if (shrinkageMetrics.by_type?.theft > 0) {
        recommendations.push('Consider additional security cameras or staff monitoring');
    }
    
    if (shrinkageMetrics.by_type?.spoilage > 0) {
        recommendations.push('Review stock rotation and expiry date management');
    }
    
    return recommendations;
}

// Save user metric preferences
router.post('/users/:userId/metric-preferences', async (req, res) => {
    try {
        const { userId } = req.params;
        const { preferences } = req.body; // Array of {category, metric_key, is_enabled}
        
        const client = await db.connect();
        
        try {
            await client.query('BEGIN');
            
            for (const pref of preferences) {
                await client.query(`
                    INSERT INTO user_metric_preferences (user_id, category, metric_key, is_enabled)
                    VALUES ($1, $2, $3, $4)
                    ON CONFLICT (user_id, category, metric_key) 
                    DO UPDATE SET is_enabled = $4, updated_at = CURRENT_TIMESTAMP
                `, [userId, pref.category, pref.metric_key, pref.is_enabled]);
            }
            
            await client.query('COMMIT');
            res.json({ success: true, message: 'Preferences saved' });
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    } catch (error) {
        res.status(500).json({ error: 'Failed to save preferences' });
    }
});

module.exports = router;