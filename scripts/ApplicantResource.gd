extends Resource
class_name ApplicantResource

@export_group("Basic Info")
@export var applicant_name: String = "John Doe"
@export_multiline var summary_text: String = "Impeccable resume, 15 years experience."

@export_group("Ethics & Evidence")
@export var is_unethical: bool = false
@export_multiline var hidden_evidence_text: String = "CONVICTED ANIMAL ABUSER"
