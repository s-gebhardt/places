
export class FieldType {
	fieldColor: string;
	name: "EMPTY" | "CONFIGURED";

	constructor(fieldColor: string, name: "EMPTY" | "CONFIGURED" = "EMPTY") {
		this.fieldColor = fieldColor;
		this.name = name;
	}
}