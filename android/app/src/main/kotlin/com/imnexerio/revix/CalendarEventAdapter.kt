package com.imnexerio.revix

import android.content.Context
import android.content.Intent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class CalendarEventAdapter(
    private var events: List<CalendarEvent>,
    private val context: Context
) : RecyclerView.Adapter<CalendarEventAdapter.EventViewHolder>() {

    class EventViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val colorBar: View = view.findViewById(R.id.event_color_bar)
        val titleText: TextView = view.findViewById(R.id.event_title)
        val descriptionText: TextView = view.findViewById(R.id.event_description)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): EventViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.calendar_event_item, parent, false)
        return EventViewHolder(view)
    }

    override fun onBindViewHolder(holder: EventViewHolder, position: Int) {
        val event = events[position]
        
        // Set title: Category > Subcategory > Title
        holder.titleText.text = "${event.category} > ${event.subCategory} > ${event.recordTitle}"
        
        // Set description
        holder.descriptionText.text = event.description
        
        // Set left bar color based on entry_type (dynamic color)
        if (event.entryType.isNotEmpty()) {
            val color = LectureColors.getLectureTypeColorSync(context, event.entryType)
            holder.colorBar.setBackgroundColor(color)
        }
        
        // Set click listener to launch AlarmScreenActivity with DETAILS_MODE=true
        holder.itemView.setOnClickListener {
            val intent = Intent(context, AlarmScreenActivity::class.java).apply {
                putExtra(AlarmScreenActivity.EXTRA_CATEGORY, event.category)
                putExtra(AlarmScreenActivity.EXTRA_SUB_CATEGORY, event.subCategory)
                putExtra(AlarmScreenActivity.EXTRA_RECORD_TITLE, event.recordTitle)
                putExtra("entry_type", event.entryType)
                putExtra("description", event.description)
                putExtra("DETAILS_MODE", true) // Always open in details mode from calendar
            }
            context.startActivity(intent)
        }
    }

    override fun getItemCount() = events.size

    fun updateEvents(newEvents: List<CalendarEvent>) {
        events = newEvents
        notifyDataSetChanged()
    }
}
