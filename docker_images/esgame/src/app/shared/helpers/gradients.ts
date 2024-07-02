export class Gradient {
	constructor(startingColor: string, endingColor: string, colors: string[]) {
		this.startingColor = startingColor;
		this.endingColor = endingColor;
		this.colors = colors;
	}

	colors: string[];
	startingColor: string;
	endingColor: string;

	calculateColor(ratio: number) : string {
		const hex = (x: number) => {
			const strValue = x.toString(16);
			return (strValue.length == 1) ? '0' + strValue : strValue;
		};

		let color = this.calculateColorRGB(ratio);

        return hex(color[0]) + hex(color[1]) + hex(color[2]);

	}

	calculateColorRGB(ratio: number) : number[] {
		let r = Math.ceil(parseInt(this.startingColor.substring(0, 2), 16) * ratio + parseInt(this.endingColor.substring(0, 2), 16) * (1 - ratio));
		let g = Math.ceil(parseInt(this.startingColor.substring(2, 4), 16) * ratio + parseInt(this.endingColor.substring(2, 4), 16) * (1 - ratio));
		let b = Math.ceil(parseInt(this.startingColor.substring(4, 6), 16) * ratio + parseInt(this.endingColor.substring(4, 6), 16) * (1 - ratio));

		return [r, g, b];
	}
}

let gradients: Map<string, Gradient> = new Map<string, Gradient>();
gradients.set('blue', new Gradient("eff3ff", "08519c", ['#d2b188', '#eff3ff', '#bdd7e7', '#6baed6', '#3182bd', '#08519c']));
gradients.set('green', new Gradient("edf8e9", "006d2c", ['#d2b188', '#edf8e9', '#bae4b3', '#74c476', '#31a354', '#006d2c']));
gradients.set('orange', new Gradient("feedde", "a63603", ['#d2b188', '#feedde', '#fdbe85', '#fd8d3c', '#e6550d', '#a63603']));
gradients.set('purple', new Gradient("f2f0f7", "54278f", ['#d2b188', '#f2f0f7', '#cbc9e2', '#9e9ac8', '#756bb1', '#54278f']));
gradients.set('red', new Gradient("F8F27D", "A80000", ['#d2b188', '#fee5d9', '#fcae91', '#fb6a4a', '#de2d26', '#a50f15']));
gradients.set('yellow', new Gradient("FDF6EE", "5D2124", ['#d2b188', '#F8F27D', '#F7D068', '#F6A825', '#AE5322', '#670B0D']));

export default gradients;

export enum DefaultGradients {
	Blue = 'blue',
	Green = 'green',
	Orange = 'orange',
	Purple = 'purple',
	Red = 'red',
	Yellow = 'yellow'
}

export class CustomColors {
	private colors = new Map<number, string>();
	id: string;

	constructor(id: string) {
		this.id = id;
	}

	get(i: number) {
		const returnVal = this.colors.get(i);
		if (!returnVal) return "#FFFFFF";
		return returnVal;
	}

	set(key: number, value: string) {
		this.colors.set(key, value);
	}

	addTransparencyToColors(transparencyHex: string) {
		this.colors.forEach((value, key) => {
			this.colors.set(key, value.slice(0, 7) + transparencyHex);
		});
	}

	getRgb(i: number) {
		return this.colorToRgb(this.colors.get(i));
	}

	colorToRgb(hex: string | undefined) {
		if (!hex) return [255, 255, 255, 0];
		const r = hex.slice(1, 3);
		const g = hex.slice(3, 5);
		const b = hex.slice(5, 7);
		const a = hex.slice(7, 9);
		if (a) {
			return [parseInt(r, 16), parseInt(g, 16), parseInt(b, 16), parseInt(a, 16)];
		}

		return [parseInt(r, 16), parseInt(g, 16), parseInt(b, 16), 255];
	}
}
