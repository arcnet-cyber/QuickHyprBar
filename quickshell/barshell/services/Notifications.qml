import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Item {
    id: root
    
    property ListModel notificationModel: ListModel {}
    
    property NotificationServer server: NotificationServer {
        id: notifServer
        
        bodySupported: true
        actionsSupported: true
        actionIconsSupported: false
        bodyMarkupSupported: false
        keepOnReload: true
        
        onNotification: (notification) => {
            notificationModel.append({
                "id": notification.id,
                "summary": notification.summary || "",
                "body": notification.body || "",
                "appName": notification.appName || "Unknown",
                "appIcon": notification.appIcon || "",
                "urgency": notification.urgency || 0,
                "expireTimeout": notification.expireTimeout || 5000,
                "timestamp": new Date(),
                "notificationRef": notification
            })
            
            root.unreadCount++
            root.newNotification(notification)
            console.log("Notification from:", notification.appName, ":", notification.summary)
        }
    }
    
    property int unreadCount: 0
    property var notifications: notificationModel
    
    signal newNotification(Notification notification)
    
    function getUnreadCount() { return unreadCount }
    function markAllRead() { unreadCount = 0 }
    
    function dismissAll() {
        for (var i = notificationModel.count - 1; i >= 0; i--) {
            var entry = notificationModel.get(i)
            if (entry && entry.notificationRef) {
                entry.notificationRef.close(NotificationCloseReason.UserDismissed)
            }
        }
        notificationModel.clear()
        unreadCount = 0
    }
    
    function dismissById(id) {
        for (var i = 0; i < notificationModel.count; i++) {
            var entry = notificationModel.get(i)
            if (entry && entry.id === id) {
                if (entry.notificationRef) {
                    entry.notificationRef.close(NotificationCloseReason.UserDismissed)
                }
                notificationModel.remove(i)
                return
            }
        }
    }
    
    function dismissByApp(appName) {
        for (var i = notificationModel.count - 1; i >= 0; i--) {
            var entry = notificationModel.get(i)
            if (entry && entry.appName === appName) {
                if (entry.notificationRef) {
                    entry.notificationRef.close(NotificationCloseReason.UserDismissed)
                }
                notificationModel.remove(i)
            }
        }
        if (notificationModel.count === 0) unreadCount = 0
    }
}
