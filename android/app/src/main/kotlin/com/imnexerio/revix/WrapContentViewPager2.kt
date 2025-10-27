package com.imnexerio.revix

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import androidx.viewpager2.widget.ViewPager2

/**
 * Wrapper for ViewPager2 that enables wrap_content height
 * by measuring the RecyclerView child and adjusting accordingly
 */
class WrapContentViewPager2 @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private var viewPager: ViewPager2? = null

    override fun onFinishInflate() {
        super.onFinishInflate()
        // Find the ViewPager2 child
        if (childCount > 0 && getChildAt(0) is ViewPager2) {
            viewPager = getChildAt(0) as ViewPager2
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val heightMode = MeasureSpec.getMode(heightMeasureSpec)
        
        // Only do custom measurement if height is wrap_content or at_most
        if ((heightMode == MeasureSpec.UNSPECIFIED || heightMode == MeasureSpec.AT_MOST) && viewPager != null) {
            var maxHeight = 0
            
            // Measure the ViewPager2's RecyclerView child
            val vp = viewPager!!
            for (i in 0 until vp.childCount) {
                val child = vp.getChildAt(i)
                child.measure(
                    widthMeasureSpec,
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
                )
                val childHeight = child.measuredHeight
                if (childHeight > maxHeight) {
                    maxHeight = childHeight
                }
            }
            
            if (maxHeight > 0) {
                // Set the measured height
                val newHeightMeasureSpec = MeasureSpec.makeMeasureSpec(maxHeight, MeasureSpec.EXACTLY)
                super.onMeasure(widthMeasureSpec, newHeightMeasureSpec)
                return
            }
        }
        
        // Default measurement
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }
}
