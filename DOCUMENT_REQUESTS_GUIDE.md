# 📄 Guide d'implémentation - Demandes de documents

## **Modèle Odoo requis : `hr.document.request`**

### **Structure du modèle :**

```python
class HrDocumentRequest(models.Model):
    _name = 'hr.document.request'
    _description = 'Document Requests'
    _order = 'request_date desc'
    
    # Champs de base
    employee_id = fields.Many2one('hr.employee', 'Employee', required=True)
    document_type = fields.Selection([
        ('salary_certificate', 'Attestation de salaire'),
        ('work_certificate', 'Attestation de travail'),
        ('payslip', 'Bulletin de paie'),
        ('mission_order', 'Ordre de mission'),
    ], string='Type de document', required=True)
    
    # Champs spécifiques aux attestations de salaire
    certificate_type = fields.Selection([
        ('monthly', 'Mensuel'),
        ('annual', 'Annuel'),
    ], string='Type d\'attestation')
    fiscal_year = fields.Integer('Année fiscale')
    with_detail = fields.Boolean('Avec détail')
    
    # Champs spécifiques aux bulletins de paie
    month = fields.Integer('Mois')
    year = fields.Integer('Année')
    
    # Champs spécifiques aux ordres de mission
    mission_type = fields.Selection([
        ('trip', 'Déplacement'),
        ('expense', 'Note de frais'),
    ], string='Type de mission')
    description = fields.Text('Description')
    start_date = fields.Datetime('Date de début')
    end_date = fields.Datetime('Date de fin')
    
    # Champs de statut
    status = fields.Selection([
        ('pending', 'En attente'),
        ('approved', 'Approuvé'),
        ('rejected', 'Rejeté'),
        ('completed', 'Terminé'),
    ], string='Statut', default='pending')
    
    # Champs de dates
    request_date = fields.Datetime('Date de demande', default=fields.Datetime.now)
    approved_date = fields.Datetime('Date d\'approbation')
    completed_date = fields.Datetime('Date de finalisation')
    
    # Champs de gestion
    approved_by = fields.Many2one('res.users', 'Approuvé par')
    notes = fields.Text('Notes')
    document_attachment = fields.Many2one('ir.attachment', 'Document généré')
    
    @api.modelnoti
    def create(self, vals):
        record = super().create(vals)
        # Envoyer fication au RH/Manager
        record._notify_hr()
        return record
    
    def _notify_hr(self):
        """Notifier le RH de la nouvelle demande"""
        # Implémenter la logique de notification
        pass
    
    def approve_request(self):
        """Approuver la demande"""
        self.write({
            'status': 'approved',
            'approved_date': fields.Datetime.now(),
            'approved_by': self.env.user.id,
        })
    
    def reject_request(self):
        """Rejeter la demande"""
        self.write({
            'status': 'rejected',
            'approved_date': fields.Datetime.now(),
            'approved_by': self.env.user.id,
        })
    
    def complete_request(self):
        """Marquer comme terminé"""
        self.write({
            'status': 'completed',
            'completed_date': fields.Datetime.now(),
        })
```

## **Vues Odoo requises :**

### **1. Vue liste des demandes :**

```xml
<record id="view_hr_document_request_tree" model="ir.ui.view">
    <field name="name">hr.document.request.tree</field>
    <field name="model">hr.document.request</field>
    <field name="arch" type="xml">
        <tree string="Demandes de documents">
            <field name="employee_id"/>
            <field name="document_type"/>
            <field name="status"/>
            <field name="request_date"/>
            <field name="approved_by"/>
        </tree>
    </field>
</record>
```

### **2. Vue formulaire des demandes :**

```xml
<record id="view_hr_document_request_form" model="ir.ui.view">
    <field name="name">hr.document.request.form</field>
    <field name="model">hr.document.request</field>
    <field name="arch" type="xml">
        <form string="Demande de document">
            <sheet>
                <group>
                    <group>
                        <field name="employee_id"/>
                        <field name="document_type"/>
                        <field name="status"/>
                    </group>
                    <group>
                        <field name="request_date"/>
                        <field name="approved_date"/>
                        <field name="completed_date"/>
                    </group>
                </group>
                
                <notebook>
                    <page string="Détails" name="details">
                        <group>
                            <field name="certificate_type" attrs="{'invisible': [('document_type', '!=', 'salary_certificate')]}"/>
                            <field name="fiscal_year" attrs="{'invisible': [('document_type', '!=', 'salary_certificate')]}"/>
                            <field name="with_detail" attrs="{'invisible': [('document_type', '!=', 'salary_certificate')]}"/>
                            
                            <field name="month" attrs="{'invisible': [('document_type', '!=', 'payslip')]}"/>
                            <field name="year" attrs="{'invisible': [('document_type', '!=', 'payslip')]}"/>
                            
                            <field name="mission_type" attrs="{'invisible': [('document_type', '!=', 'mission_order')]}"/>
                            <field name="description" attrs="{'invisible': [('document_type', '!=', 'mission_order')]}"/>
                            <field name="start_date" attrs="{'invisible': [('document_type', '!=', 'mission_order')]}"/>
                            <field name="end_date" attrs="{'invisible': [('document_type', '!=', 'mission_order')]}"/>
                        </group>
                    </page>
                    
                    <page string="Gestion" name="management">
                        <group>
                            <field name="approved_by"/>
                            <field name="notes"/>
                            <field name="document_attachment"/>
                        </group>
                    </page>
                </notebook>
            </sheet>
        </form>
    </field>
</record>
```

### **3. Action et menu :**

```xml
<record id="action_hr_document_request" model="ir.actions.act_window">
    <field name="name">Demandes de documents</field>
    <field name="res_model">hr.document.request</field>
    <field name="view_mode">tree,form</field>
    <field name="view_id" ref="view_hr_document_request_tree"/>
</record>

<menuitem id="menu_hr_document_request"
          name="Demandes de documents"
          parent="hr.menu_hr_root"
          action="action_hr_document_request"
          sequence="20"/>
```

## **Permissions et groupes :**

### **Groupe pour les employés :**
```xml
<record id="group_hr_employee_document_request" model="res.groups">
    <field name="name">Employé - Demandes de documents</field>
    <field name="category_id" ref="hr.module_category_human_resources"/>
    <field name="implied_ids" eval="[(4, ref('base.group_user'))]"/>
</record>
```

### **Règles d'accès :**
```xml
<record id="hr_document_request_employee_rule" model="ir.rule">
    <field name="name">Employé: voir ses propres demandes</field>
    <field name="model_id" ref="model_hr_document_request"/>
    <field name="domain_force">[('employee_id.user_id', '=', user.id)]</field>
    <field name="groups" eval="[(4, ref('group_hr_employee_document_request'))]"/>
</record>

<record id="hr_document_request_hr_rule" model="ir.rule">
    <field name="name">RH: voir toutes les demandes</field>
    <field name="model_id" ref="model_hr_document_request"/>
    <field name="domain_force">[(1, '=', 1)]</field>
    <field name="groups" eval="[(4, ref('hr.group_hr_manager'))]"/>
</record>
```

## **Workflow de traitement :**

1. **Demande créée** → Statut: `pending`
2. **Notification RH** → Email/notification automatique
3. **Approbation RH** → Statut: `approved`
4. **Génération document** → Upload du document généré
5. **Finalisation** → Statut: `completed`
6. **Notification employé** → Document disponible

## **Intégration avec l'app Flutter :**

L'app Flutter appelle les méthodes suivantes :
- `requestSalaryCertificate()` → Crée une demande d'attestation de salaire
- `requestWorkCertificate()` → Crée une demande d'attestation de travail
- `requestPayslip()` → Crée une demande de bulletin de paie
- `requestMissionOrder()` → Crée une demande d'ordre de mission

Toutes ces méthodes créent des enregistrements dans le modèle `hr.document.request` avec le statut `pending`.

## **Notifications :**

Utiliser le système de notifications Odoo existant pour :
- Notifier le RH des nouvelles demandes
- Notifier l'employé de l'approbation/rejet
- Notifier l'employé de la disponibilité du document

## **Génération automatique de documents :**

Pour chaque type de document, créer des méthodes de génération :
- `_generate_salary_certificate()` → Génère l'attestation de salaire
- `_generate_work_certificate()` → Génère l'attestation de travail
- `_generate_payslip()` → Génère le bulletin de paie
- `_generate_mission_order()` → Génère l'ordre de mission

Ces méthodes peuvent utiliser des templates Odoo ou des bibliothèques Python comme `reportlab` pour générer des PDF.
