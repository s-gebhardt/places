export class Legend {
    elements: LegendElement[];
	isNegative = false;
    isGradient = false;
}

export class LegendElement {
    forValue: number;
    color: string;
}