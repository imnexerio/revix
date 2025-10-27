package com.imnexerio.revix

import android.content.Context
import android.content.Intent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class CalendarEventAdapter(
    private var items: List<Any>,
    private val context: Context
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    companion object {
        private const val VIEW_TYPE_SEPARATOR = 0
        private const val VIEW_TYPE_EVENT = 1
    }

    class EventViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val colorBar: View = view.findViewById(R.id.event_color_bar)
        val titleText: TextView = view.findViewById(R.id.event_title)
        val descriptionText: TextView = view.findViewById(R.id.event_description)
    }

    class SeparatorViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val separatorText: TextView = view.findViewById(R.id.separator_text)
    }

    override fun getItemViewType(position: Int): Int {
        return when (items[position]) {
            is String -> VIEW_TYPE_SEPARATOR
            is CalendarEvent -> VIEW_TYPE_EVENT
            else -> VIEW_TYPE_EVENT
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        return when (viewType) {
            VIEW_TYPE_SEPARATOR -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.calendar_separator_item, parent, false)
                SeparatorViewHolder(view)
            }
            else -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.calendar_event_item, parent, false)
                EventViewHolder(view)
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        when (holder) {
            is SeparatorViewHolder -> {
                val separator = items[position] as String
                holder.separatorText.text = separator
            }
            is EventViewHolder -> {
                val event = items[position] as CalendarEvent
                
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
        }
    }

    override fun getItemCount() = items.size

    fun updateEvents(newItems: List<Any>) {
        items = newItems
        notifyDataSetChanged()
    }
}
