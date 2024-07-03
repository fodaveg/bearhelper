import Foundation
import EventKit

class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var selectedCalendarIDs: [String] = []

    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func addEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            completion(true, nil)
        } catch let error {
            completion(false, error)
        }
    }

    func fetchEvents(startDate: Date, endDate: Date) -> [EKEvent]? {
        let selectedCalendars = self.selectedCalendars()
        guard !selectedCalendars.isEmpty else {
            print("No calendars selected.")
            return []
        }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
        return eventStore.events(matching: predicate)
    }

    func getCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }

    func selectedCalendars() -> [EKCalendar] {
        let calendars = eventStore.calendars(for: .event)
        return calendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
    }
}

