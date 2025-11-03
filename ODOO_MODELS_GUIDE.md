# 📋 Odoo Models Used in the Application

## **Actual Odoo Models in Use**

This document describes the **exact Odoo models** that are currently used in the Flutter application. The app uses **standard Odoo models** that come with Odoo by default - **NO custom models are required**.

---

## **1. Task Management: `project.task`**

### **Model Used:**
- **Name**: `project.task` (Standard Odoo Project Task model)
- **Module**: `project` (Odoo Project Management module)

### **Fields Used by the App:**
```python
# Basic task fields
'id'                    # Task ID
'name'                  # Task title
'description'           # Task description (HTML)
'priority'              # Task priority (0=Normal, 1=High, -1=Low)
'date_deadline'         # Due date
'create_date'           # Creation date
'write_date'            # Last update date

# Assignment fields
'user_ids'              # Many2many: Assigned employees (user_ids field)
'create_uid'            # Creator user ID

# Status fields
'stage_id'              # Many2one: Current stage (default project stages)
'personal_stage_type_id' # Many2one: Personal stage (for project_todo module)
'active'                # Boolean: Task active/inactive

# Project fields
'project_id'            # Many2one: Project (optional)
'partner_id'            # Many2one: Customer (optional)
```

### **How It Works:**
1. **Task Creation**: Manager creates tasks using `project.task.create()`
2. **Task Assignment**: Tasks assigned via `user_ids` (many2many field)
3. **Task Status**: Status managed via `stage_id` or `personal_stage_type_id`
4. **Task Filtering**: Employee sees only tasks where their `user_id` is in `user_ids`

### **Stage Types Used:**
- Tasks use `project.task.type` model for available stages
- Common stages: "To Do", "In Progress", "Done", "Cancelled"
- App maps stage names to status: `pending`, `in_progress`, `completed`

---

## **2. Notifications: `mail.message`**

### **Model Used:**
- **Name**: `mail.message` (Standard Odoo Mail Message model)
- **Module**: `mail` (Odoo Mail module)

### **Fields Used by the App:**
```python
# Basic message fields
'id'                    # Message ID
'subject'               # Notification title
'body'                  # Notification message (HTML)
'message_type'          # Type: 'notification' for app notifications
'create_date'           # Creation date

# Recipient fields
'partner_ids'           # Many2many: Recipient users (res.partner)
'author_id'             # Many2one: Sender user

# Status fields
'is_read'               # Boolean: Read status (via mail.notification sub-model)
```

### **How It Works:**
1. **Send Notification**: Creates `mail.message` with `message_type='notification'`
2. **Target Recipients**: Uses `partner_ids` to specify recipient users
3. **Read Status**: Tracks read status via `mail.notification` sub-model
4. **Fetch Notifications**: Employee fetches messages where `partner_ids` contains their user

---

## **3. Employee Management: `hr.employee`**

### **Model Used:**
- **Name**: `hr.employee` (Standard Odoo HR Employee model)
- **Module**: `hr` (Odoo Human Resources module)

### **Fields Used by the App:**
```python
# Basic employee fields
'id'                    # Employee ID
'name'                  # Employee name
'work_email'            # Work email
'work_phone'            # Work phone
'mobile_phone'          # Mobile phone
'birthday'              # Birth date

# Assignment fields
'user_id'               # Many2one: Associated res.users account
'parent_id'             # Many2one: Manager (another hr.employee)
'job_id'                # Many2one: Job position
'department_id'         # Many2one: Department

# Image field
'image_1920'            # Binary: Employee photo (base64 encoded)
```

---

## **4. Leave Management: `hr.leave`**

### **Model Used:**
- **Name**: `hr.leave` (Standard Odoo Leave Request model)
- **Module**: `hr_holidays` (Odoo Leave Management module)

### **Fields Used by the App:**
```python
# Basic leave fields
'id'                    # Leave request ID
'name'                  # Reason/description
'request_date_from'     # Start date
'request_date_to'       # End date
'request_unit_half'     # Boolean: Half-day leave
'state'                 # Status: 'draft', 'confirm', 'validate1', 'validate', 'refuse'

# Assignment fields
'employee_id'           # Many2one: Employee
'holiday_status_id'     # Many2one: Leave type (hr.leave.type)
```

### **Related Models:**
- **`hr.leave.type`**: Leave types (Annual, Sick, etc.)
- **`hr.leave.allocation`**: Leave allocations/balance
- **`hr.leave.employee.type.report`**: Leave balance reports

---

## **5. Attendance Management: `hr.attendance`**

### **Model Used:**
- **Name**: `hr.attendance` (Standard Odoo Attendance model)
- **Module**: `hr_attendance` (Odoo Attendance module)

### **Fields Used by the App:**
```python
# Basic attendance fields
'id'                    # Attendance record ID
'check_in'              # Datetime: Check-in time
'check_out'             # Datetime: Check-out time
'worked_hours'          # Float: Total worked hours

# Location fields
'in_latitude'           # Float: Check-in latitude
'in_longitude'          # Float: Check-in longitude
'out_latitude'          # Float: Check-out latitude
'out_longitude'         # Float: Check-out longitude

# Assignment fields
'employee_id'           # Many2one: Employee
```

---

## **6. User Management: `res.users`**

### **Model Used:**
- **Name**: `res.users` (Standard Odoo User model)
- **Module**: `base` (Odoo Base module)

### **Fields Used by the App:**
```python
# Basic user fields
'id'                    # User ID
'name'                  # User name
'email'                 # Email address
'login'                 # Login username
```

---

## **Summary: Models Actually Used**

| Purpose | Odoo Model | Module | Custom? |
|---------|-----------|--------|---------|
| Tasks | `project.task` | `project` | ❌ Standard |
| Notifications | `mail.message` | `mail` | ❌ Standard |
| Employees | `hr.employee` | `hr` | ❌ Standard |
| Leave Requests | `hr.leave` | `hr_holidays` | ❌ Standard |
| Leave Types | `hr.leave.type` | `hr_holidays` | ❌ Standard |
| Leave Balance | `hr.leave.allocation` | `hr_holidays` | ❌ Standard |
| Attendance | `hr.attendance` | `hr_attendance` | ❌ Standard |
| Users | `res.users` | `base` | ❌ Standard |
| Task Stages | `project.task.type` | `project` | ❌ Standard |

---

## **⚠️ Important: Custom Models NOT Used**

The following custom models are **NOT** used in the application:

- ❌ `manager.task` - **NOT USED** (App uses `project.task` instead)
- ❌ `manager.notification` - **NOT USED** (App uses `mail.message` instead)

These custom models were originally planned but **replaced with standard Odoo models** for immediate functionality without requiring custom Odoo development.

---

## **✅ What This Means**

1. **No Custom Odoo Development Required**: The app works with standard Odoo modules
2. **Immediate Functionality**: Works out of the box with existing Odoo installations
3. **Standard Workflows**: Uses Odoo's standard project and HR workflows
4. **Easy Integration**: Integrates with existing Odoo modules

---

## **📝 Notes**

- The app uses standard Odoo models that come with Odoo by default
- No custom Python models need to be created in Odoo
- The app is compatible with standard Odoo installations
- All functionality uses existing Odoo API endpoints

---

## **🔄 If You Want Custom Models**

If you want to implement custom models (`manager.task`, `manager.notification`), you would need to:
1. Create the custom models in Odoo (see original guide structure)
2. Update the Flutter app to use the new models
3. Migrate existing data from standard models to custom models

However, **this is not required** - the app works perfectly with standard Odoo models.
