# 🔔 Odoo-Based Notifications Implementation Guide

## **How Notifications Work with Pure Odoo**

### **📱 Complete Flow:**

1. **Manager assigns task** → App sends notification to Odoo
2. **Odoo processes** → Creates notification record in database
3. **App polls Odoo** → Checks for new notifications every 30 seconds
4. **Employee receives** → Local notification appears on device
5. **Employee opens** → App navigates to relevant screen

---

## **🛠️ Implementation Details**

### **1. Dependencies (Simplified)**
```yaml
# pubspec.yaml
dependencies:
  flutter_local_notifications: ^16.3.2  # Only local notifications needed
```

### **2. Odoo Notification Service**
- **File**: `lib/services/push_notification_service.dart` (renamed to `OdooNotificationService`)
- **Features**:
  - ✅ Odoo polling for notifications
  - ✅ Local notifications display
  - ✅ Permission requests
  - ✅ Background polling
  - ✅ Notification navigation

### **3. Odoo Integration**
- **File**: `lib/services/odoo_service.dart`
- **New Methods**:
  - `getUnreadNotifications()` - Fetch notifications from Odoo
  - `markNotificationAsRead()` - Mark notifications as read
  - `sendNotificationToEmployee()` - Send notification via Odoo
  - `sendTaskAssignmentNotification()` - Specific task notifications
  - `sendLeaveApprovalNotification()` - Leave status notifications

### **4. Notification Model**
- **File**: `lib/data/models/notification_model.dart`
- **Features**:
  - ✅ Type-safe notification data
  - ✅ Serialization/deserialization
  - ✅ Notification type enum

---

## **🔧 Odoo Backend Requirements**

### **Required Odoo Models:**

#### **1. Create HR Notification Model**
```python
class HrNotification(models.Model):
    _name = 'hr.notification'
    _description = 'HR Notifications'
    _order = 'create_date desc'
    
    title = fields.Char('Title', required=True)
    message = fields.Text('Message', required=True)
    type = fields.Selection([
        ('task_assignment', 'Task Assignment'),
        ('leave_approval', 'Leave Approval'),
        ('general', 'General'),
        ('system', 'System'),
    ], string='Type', default='general')
    employee_id = fields.Many2one('hr.employee', 'Employee', required=True)
    data = fields.Text('Additional Data', help='JSON data for notification')
    is_read = fields.Boolean('Is Read', default=False)
    read_date = fields.Datetime('Read Date')
    create_date = fields.Datetime('Created At', default=fields.Datetime.now)
    
    @api.model
    def create(self, vals):
        record = super().create(vals)
        # Log notification creation
        _logger.info(f"Created notification for employee {record.employee_id.name}: {record.title}")
        return record
    
    def mark_as_read(self):
        """Mark notification as read"""
        self.write({
            'is_read': True,
            'read_date': fields.Datetime.now()
        })
```

#### **2. Add Notification Methods to HR Employee**
```python
# In hr.employee model, add these methods:

def send_notification(self, title, message, notification_type='general', data=None):
    """Send notification to this employee"""
    self.env['hr.notification'].create({
        'title': title,
        'message': message,
        'type': notification_type,
        'employee_id': self.id,
        'data': json.dumps(data) if data else '{}',
    })

def get_unread_notifications(self):
    """Get unread notifications for this employee"""
    return self.env['hr.notification'].search([
        ('employee_id', '=', self.id),
        ('is_read', '=', False)
    ])
```

---

## **📱 Mobile App Behavior**

### **Notification Scenarios:**

#### **1. App is Open (Foreground)**
- ✅ Polls Odoo every 30 seconds
- ✅ Shows local notification for new messages
- ✅ Updates in-app notification list
- ✅ Can navigate to relevant screen

#### **2. App is in Background**
- ✅ Continues polling (if app is still active)
- ✅ Shows system notification
- ✅ Tapping opens app to relevant screen
- ✅ Updates notification count

#### **3. App is Closed**
- ❌ No polling (battery optimization)
- ✅ Next app launch will check for missed notifications
- ✅ Shows accumulated notifications

---

## **🚀 Setup Instructions**

### **1. Flutter Configuration**
```bash
# Install dependencies
flutter pub get

# For Android - add to android/app/build.gradle
android {
    compileSdkVersion 34
    // ... other config
}

# For iOS - add to ios/Runner/Info.plist
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
</array>
```

### **2. Odoo Configuration**
1. Create `hr.notification` model
2. Add notification methods to `hr.employee`
3. Test notification creation
4. Verify API access permissions

### **3. App Integration**
1. Initialize `OdooNotificationService` in `main.dart`
2. Start polling when user logs in
3. Stop polling when user logs out
4. Handle notification taps for navigation

---

## **🧪 Testing**

### **Test Scenarios:**
1. **Manager assigns task** → Check if employee receives notification
2. **Employee is offline** → Notification should appear when app opens
3. **Multiple notifications** → Should show all unread notifications
4. **Notification tap** → Should navigate to correct screen

### **Debug Commands:**
```bash
# Check notification polling
flutter logs | grep "Starting notification polling"

# Test notification creation
# Use Odoo backend to create test notification

# Check Odoo logs
# Look for notification creation logs
```

---

## **🔒 Security Considerations**

1. **API Access**: Secure Odoo API endpoints
2. **User Permissions**: Only managers can send notifications
3. **Rate Limiting**: Prevent notification spam
4. **Data Privacy**: Don't send sensitive data in notifications
5. **Polling Frequency**: Balance between responsiveness and battery usage

---

## **📊 Monitoring & Analytics**

### **Track:**
- Notification delivery rates
- User engagement (tap rates)
- Polling frequency
- Battery usage impact

### **Metrics:**
- Notifications sent per day
- User notification preferences
- App usage after notifications
- Polling efficiency

---

## **🎯 Benefits**

✅ **Pure Odoo Integration** - No external dependencies
✅ **Simplified Architecture** - Single backend system
✅ **Better Control** - Full control over notification logic
✅ **Cost Effective** - No Firebase/Google services needed
✅ **Data Privacy** - All data stays in your Odoo instance
✅ **Easy Debugging** - All logs in one place
✅ **Customizable** - Easy to extend with Odoo features

---

## **⚠️ Limitations**

❌ **No Background Notifications** - Only works when app is active
❌ **Battery Usage** - Polling consumes battery
❌ **Delayed Notifications** - Up to 30 seconds delay
❌ **No Offline Support** - Requires internet connection

---

## **🔄 Migration from Firebase**

If you're migrating from Firebase:

1. **Remove Firebase dependencies** from `pubspec.yaml`
2. **Update service imports** in `main.dart`
3. **Replace Firebase methods** with Odoo polling
4. **Update notification handling** to use local notifications
5. **Test thoroughly** to ensure all functionality works

This implementation ensures that when a manager assigns a task to Othman (or any employee), they will receive a notification when they open the app! 🚀
