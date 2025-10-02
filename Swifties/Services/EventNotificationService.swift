//
//  EventNotificationService.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//

//  EventNotificationService.swift
//  Swifties

import Foundation

class EventNotificationService {
    
    func checkEventsForUser(user: UserData, events: [Event]) {
        let freeSlots = user.preferences.notifications.freeTimeSlots
        
        for event in events {
            for day in event.schedule.days {
                for time in event.schedule.times {
                    
                    let eventSlot = "\(day) \(time)"
                    
                    if freeSlots.contains(eventSlot) {
                        if let eventDate = self.dateFrom(day: day, time: time) {
                            NotificationManager.shared.scheduleNotification(
                                title: "Nuevo evento disponible 🎉",
                                body: "\(event.name) está ocurriendo en tu tiempo libre",
                                date: eventDate
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func dateFrom(day: String, time: String) -> Date? {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "es_ES") // porque tienes los días en español
        
        // 1. Parsear la hora
        guard let timeDate = formatter.date(from: time) else { return nil }
        let hour = calendar.component(.hour, from: timeDate)
        let minute = calendar.component(.minute, from: timeDate)
        
        // 2. Mapear día en español → weekday de Calendar
        let weekdays: [String: Int] = [
            "domingo": 1,
            "lunes": 2,
            "martes": 3,
            "miércoles": 4,
            "jueves": 5,
            "viernes": 6,
            "sábado": 7,
            // English equivalents
            "sunday": 1,
            "monday": 2,
            "tuesday": 3,
            "wednesday": 4,
            "thursday": 5,
            "friday": 6,
            "saturday": 7
        ]
        
        guard let targetWeekday = weekdays[day.lowercased()] else { return nil }
        
        // 3. Encontrar la próxima fecha con ese weekday
        var nextDate = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: nextDate)
        components.hour = hour
        components.minute = minute
        
        // Avanzar hasta que el weekday coincida, usando Date y date(byAdding:)
        guard var candidateDate = calendar.date(from: components) else { return nil }
        while calendar.component(.weekday, from: candidateDate) != targetWeekday {
            guard let nextCandidate = calendar.date(byAdding: .day, value: 1, to: candidateDate) else { return nil }
            candidateDate = nextCandidate
        }
        
        // 4. Si la fecha ya pasó, buscar la próxima semana
        if candidateDate < Date() {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: candidateDate) else { return nil }
            candidateDate = nextWeek
        }
        
        return candidateDate
    }

}
