# 📋 Odoo Models Implementation Guide

## **Required Odoo Models for Manager-Employee Task Management**

To implement the complete task management system for the **Manager-Employee relationship**, you need to create these models in your Odoo backend:

---

## **1. Manager Task Model (`manager.task`)**

Create a new Python file: `addons/manager_task/models/manager_task.py`

```python
from odoo import models, fields, api
from datetime import datetime

class ManagerTask(models.Model):
    _name = 'manager.task'
    _description = 'Manager Task Management'
    _order = 'create_date desc'
    _rec_name = 'title'
    
    # Basic fields
    title = fields.Char('Task Title', required=True, translate=True)
    description = fields.Text('Description', translate=True)
    
    # Manager-Employee Assignment fields
    assigned_to_id = fields.Many2one('hr.employee', 'Assigned To Employee', required=True)
    assigned_by_id = fields.Many2one('hr.employee', 'Assigned By Manager', required=True)
    assigned_by_name = fields.Char('Manager Name', required=True)
    
    # Task details
    priority = fields.Selection([
        ('low_priority', 'Low Priority'),
        ('medium_priority', 'Medium Priority'),
        ('high_priority', 'High Priority'),
    ], string='Priority', default='medium_priority', required=True)
    
    status = fields.Selection([
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ], string='Status', default='pending', required=True)
    
    # Dates
    due_date = fields.Datetime('Due Date', required=True)
    create_date = fields.Datetime('Created Date', default=fields.Datetime.now, readonly=True)
    update_date = fields.Datetime('Last Updated', readonly=True)
    completed_date = fields.Datetime('Completed Date', readonly=True)
    
    # Additional fields
    tags = fields.Char('Tags')
    notes = fields.Text('Notes')
    
    # Computed fields
    is_overdue = fields.Boolean('Is Overdue', compute='_compute_is_overdue')
    days_remaining = fields.Integer('Days Remaining', compute='_compute_days_remaining')
    
    @api.depends('due_date', 'status')
    def _compute_is_overdue(self):
        for task in self:
            if task.status not in ['completed', 'cancelled'] and task.due_date:
                task.is_overdue = datetime.now() > task.due_date
            else:
                task.is_overdue = False
    
    @api.depends('due_date', 'status')
    def _compute_days_remaining(self):
        for task in self:
            if task.status not in ['completed', 'cancelled'] and task.due_date:
                delta = task.due_date - datetime.now()
                task.days_remaining = delta.days
            else:
                task.days_remaining = 0
    
    @api.model
    def create(self, vals):
        vals['update_date'] = fields.Datetime.now()
        return super(HrTask, self).create(vals)
    
    def write(self, vals):
        vals['update_date'] = fields.Datetime.now()
        if vals.get('status') == 'completed':
            vals['completed_date'] = fields.Datetime.now()
        return super(HrTask, self).write(vals)
    
    def action_mark_completed(self):
        self.write({'status': 'completed'})
    
    def action_mark_in_progress(self):
        self.write({'status': 'in_progress'})
    
    def action_cancel(self):
        self.write({'status': 'cancelled'})
```

---

## **2. Manager Notification Model (`manager.notification`)**

Create a new Python file: `addons/manager_notification/models/manager_notification.py`

```python
from odoo import models, fields, api
from datetime import datetime

class ManagerNotification(models.Model):
    _name = 'manager.notification'
    _description = 'Manager Notifications'
    _order = 'create_date desc'
    _rec_name = 'title'
    
    # Basic fields
    title = fields.Char('Title', required=True, translate=True)
    message = fields.Text('Message', required=True, translate=True)
    
    # Assignment fields
    employee_id = fields.Many2one('hr.employee', 'Employee', required=True)
    sender_id = fields.Many2one('hr.employee', 'Sender')
    sender_name = fields.Char('Sender Name')
    
    # Notification details
    type = fields.Selection([
        ('general', 'General'),
        ('task_assignment', 'Task Assignment'),
        ('leave_approval', 'Leave Approval'),
        ('meeting', 'Meeting'),
        ('training', 'Training'),
        ('profile_update', 'Profile Update'),
        ('evaluation', 'Evaluation'),
    ], string='Type', default='general', required=True)
    
    # Status fields
    is_read = fields.Boolean('Is Read', default=False)
    read_date = fields.Datetime('Read Date', readonly=True)
    
    # Additional data
    data = fields.Text('Additional Data')  # JSON string for extra data
    action_url = fields.Char('Action URL')
    
    # Dates
    create_date = fields.Datetime('Created Date', default=fields.Datetime.now, readonly=True)
    expiry_date = fields.Datetime('Expiry Date')
    
    # Computed fields
    is_expired = fields.Boolean('Is Expired', compute='_compute_is_expired')
    
    @api.depends('expiry_date')
    def _compute_is_expired(self):
        for notification in self:
            if notification.expiry_date:
                notification.is_expired = datetime.now() > notification.expiry_date
            else:
                notification.is_expired = False
    
    def mark_as_read(self):
        self.write({
            'is_read': True,
            'read_date': fields.Datetime.now()
        })
    
    def mark_as_unread(self):
        self.write({
            'is_read': False,
            'read_date': False
        })
    
    @api.model
    def create_notification(self, employee_id, title, message, notification_type='general', data=None, sender_name=None):
        """Helper method to create notifications"""
        vals = {
            'employee_id': employee_id,
            'title': title,
            'message': message,
            'type': notification_type,
            'data': data or '{}',
            'sender_name': sender_name or 'System',
        }
        return self.create(vals)
```

---

## **3. Model Files Structure**

Create the following file structure in your Odoo addon:

```
addons/manager_task_management/
├── __manifest__.py
├── __init__.py
├── models/
│   ├── __init__.py
│   ├── manager_task.py
│   └── manager_notification.py
├── views/
│   ├── manager_task_views.xml
│   └── manager_notification_views.xml
├── security/
│   ├── ir.model.access.csv
│   └── security.xml
└── data/
    └── demo.xml
```

---

## **4. Manifest File (`__manifest__.py`)**

```python
{
    'name': 'Manager Task Management',
    'version': '1.0.0',
    'category': 'Human Resources',
    'summary': 'Task management system for Manager-Employee relationship',
    'description': """
        Manager Task Management System
        =============================
        
        This module provides:
        * Manager to Employee task assignment
        * Direct reports task tracking
        * Manager-Employee notifications
        * Task status management
        * Priority management
        * Due date tracking
    """,
    'author': 'Your Company',
    'website': 'https://www.yourcompany.com',
    'depends': ['base', 'hr'],
    'data': [
        'security/ir.model.access.csv',
        'security/security.xml',
        'views/manager_task_views.xml',
        'views/manager_notification_views.xml',
        'data/demo.xml',
    ],
    'demo': [
        'data/demo.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}
```

---

## **5. Security Configuration**

### `security/ir.model.access.csv`
```csv
id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink
access_manager_task_user,manager.task.user,model_manager_task,hr.group_hr_user,1,1,1,0
access_manager_task_manager,manager.task.manager,model_manager_task,hr.group_hr_manager,1,1,1,1
access_manager_notification_user,manager.notification.user,model_manager_notification,hr.group_hr_user,1,0,0,0
access_manager_notification_manager,manager.notification.manager,model_manager_notification,hr.group_hr_manager,1,1,1,1
```

### `security/security.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data noupdate="1">
        <!-- Record Rules -->
        <record id="manager_task_rule_user" model="ir.rule">
            <field name="name">Manager Task: User Access</field>
            <field name="model_id" ref="model_manager_task"/>
            <field name="domain_force">[
                '|',
                ('assigned_to_id.user_id', '=', user.id),
                ('assigned_by_id.user_id', '=', user.id)
            ]</field>
            <field name="groups" eval="[(4, ref('hr.group_hr_user'))]"/>
        </record>
        
        <record id="manager_notification_rule_user" model="ir.rule">
            <field name="name">Manager Notification: User Access</field>
            <field name="model_id" ref="model_manager_notification"/>
            <field name="domain_force">[('employee_id.user_id', '=', user.id)]</field>
            <field name="groups" eval="[(4, ref('hr.group_hr_user'))]"/>
        </record>
    </data>
</odoo>
```

---

## **6. Installation Steps**

1. **Create the addon directory** in your Odoo addons folder
2. **Copy all the files** with the structure above
3. **Update the manifest** with your company details
4. **Install the module** in Odoo:
   - Go to Apps menu
   - Search for "Manager Task Management"
   - Click Install

---

## **7. API Endpoints**

Once installed, the models will be available via XML-RPC:

- **Create Task**: `manager.task.create()`
- **Read Tasks**: `manager.task.search_read()`
- **Update Task**: `manager.task.write()`
- **Create Notification**: `manager.notification.create()`
- **Read Notifications**: `manager.notification.search_read()`

---

## **8. Testing**

After installation, you can test the system by:

1. **Creating a task** via the Flutter app
2. **Checking the task** appears in Odoo backend
3. **Verifying notifications** are created
4. **Testing task fetching** from employee side

---

## **9. Troubleshooting**

### Common Issues:

1. **"Object manager.task doesn't exist"**
   - Ensure the module is properly installed
   - Check the model name in the manifest

2. **Permission errors**
   - Verify security rules are correct
   - Check user groups and access rights

3. **Data not appearing**
   - Check domain filters in search methods
   - Verify employee relationships

---

## **10. Customization**

You can extend these models by:

- Adding custom fields
- Creating computed fields
- Adding workflow states
- Integrating with other modules
- Adding email notifications
- Creating reports and dashboards

This implementation provides a complete task management system that integrates seamlessly with your Flutter app and Odoo backend.
