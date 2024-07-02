import { Component } from '@angular/core';
import { AbstractControl, FormArray, FormControl, FormGroup } from '@angular/forms';
import { TranslateService } from '@ngx-translate/core';
import { DefaultGradients } from '../shared/helpers/gradients';
import * as uuid from 'uuid';

@Component({
	selector: 'tro-configurator',
	templateUrl: './configurator.component.html',
	styleUrls: ['./configurator.component.scss']
})
export class ConfiguratorComponent {
	formGroup: FormGroup;
	languages: string[] = [];
	gradients = Object.values(DefaultGradients);

	constructor(private translate: TranslateService) {
		this.languages = translate.getLangs();
		this.initialiseForm();
	}

	initialiseForm() {
		this.formGroup = new FormGroup({
			"title": this.getLanguageControls(),
			"mapMode": new FormControl("svg"),
			"imageMode": new FormControl(false),
			"elementSize": new FormControl(2),
			"minSelected": new FormControl(0),
			"minValue": new FormControl(0),
			"maxValue": new FormControl(100),
			"highlightColor": new FormControl("#000000"),
			"infiniteLevels": new FormControl(false),
			"gameBoardColumns": new FormControl(28),
			"gameBoardRows": new FormControl(29),
			"calcUrl": new FormControl({ value: "", disabled: true }),
			"productionTypes": new FormArray([]),
			"defaultProductionType": new FormControl(""),
			"maps": new FormArray([]),
			"customColors": new FormArray([]),
			"basicInstructions": this.getLanguageControls(),
			"basicInstructionsImageUrl": new FormControl(""),
			"advancedInstructions": this.getLanguageControls(),
			"advancedInstructionsImageUrl": new FormControl(""),
		});
		this.toggleMapMode('svg');
		this.formGroup.get('mapMode')!.valueChanges.subscribe((value) => {
			this.toggleMapMode(value);
		});
	}

	get productionTypes() {
		return this.formGroup.get('productionTypes') as FormArray;
	}

	get maps() {
		return this.formGroup.get('maps') as FormArray;
	}

	get customColors() {
		return this.formGroup.get('customColors') as FormArray;
	}

	addMap() {
		let fg = new FormGroup({
			id: new FormControl((this.maps.length + 1) * 10),
			name: this.getLanguageControls(),
			gradient: new FormControl("blue"),
			productionTypes: new FormControl([]),
			gameBoardType: new FormControl("Suitability"),
			urlToData: new FormControl(""),
			customColorId: new FormControl({value: "", disabled: true})
		});
		this.maps.push(fg);
		fg.get('gradient')!.valueChanges.subscribe((value) => {
			if (value == "custom") {
				fg.get('customColorId')?.enable();
			} else {
				fg.get('customColorId')?.disable();
			}
		});
		fg.get('gameBoardType')!.valueChanges.subscribe(value => {
			if (this.formGroup.get('mapMode')?.value == 'grid') return;
			if (value == "Consequence") {
				fg.get('urlToData')?.disable();
			} else {
				fg.get('urlToData')?.enable();
			}
			if (value == 'Drawing') {
				fg.get('productionTypes')?.disable();
				fg.get('gradient')?.disable();
			} else {
				fg.get('productionTypes')?.enable();
				fg.get('gradient')?.enable();
			}
		});
	}

	removeMap(index: number) {
		this.maps.removeAt(index);
	}

	addProductionType() {
		this.productionTypes.push(new FormGroup({
			id: new FormControl((this.productionTypes.length + 1) * 11),
			name: this.getLanguageControls(),
			fieldColor: new FormControl("#000000"),
			urlToIcon: new FormControl(""),
			maxElements: new FormControl(0)
		}));
	}

	addCustomColors(addEmpty = false) {
		this.customColors.push(new FormGroup({
			id: new FormControl(uuid.v4()),
			colors: new FormArray([])
		}));
		if (!addEmpty) {
			this.addColor(this.customColors.controls[this.customColors.controls.length - 1]);
		}
	}

	addColor(formGroup: AbstractControl) {
		this.getColorsArray(formGroup).push(new FormGroup({
			number: new FormControl(),
			color: new FormControl("#000000")
		}));
	}

	removeColor(formGroup: AbstractControl, index: number) {
		this.getColorsArray(formGroup).removeAt(index);
	}

	removeColorSet(index: number) {
		this.customColors.removeAt(index);
	}

	getColorsArray(formGroup: AbstractControl) {
		return formGroup.get('colors') as FormArray;
	}

	removeProductionType(index: number) {
		this.productionTypes.removeAt(index);
	}

	getLanguageControls() {
		let fg = new FormGroup({});
		this.languages.forEach((lang) => {
			fg.addControl(lang, new FormControl());
		});
		return fg;
	}

	exportData() {
		const data = JSON.stringify(this.formGroup.getRawValue());
		let a = document.createElement('a');
		a.href = `data:text/json;charset=utf-8,${encodeURIComponent(data)}`;
		a.download = 'configuration.json';
		a.click();
	}

	onFileSelected(event: Event) {
		const file: File = (event.target as HTMLInputElement).files![0];
		if (file) {
			const reader = new FileReader();
			reader.onload = (e: any) => {
				const contents = e.target.result;
				let value = JSON.parse(contents);
				value.maps?.forEach((_: any) => {
					this.addMap();
				});
				value.productionTypes?.forEach((_: any) => {
					this.addProductionType();
				});
				value.customColors?.forEach((customColor: any) => {
					this.addCustomColors(true);
					customColor.colors?.forEach((color: any, index: number) => {
						this.addColor(this.customColors.controls[this.customColors.controls.length - 1]);
					});
				});
				this.formGroup.patchValue(value);

			};
			reader.readAsText(file);
		}
	}

	toggleMapMode(value: string) {
		if (value == "svg") {
			this.formGroup.get('elementSize')!.disable();
			this.formGroup.get('elementSize')!.setValue(1);
			this.formGroup.get('imageMode')!.disable();
			this.formGroup.get('imageMode')!.setValue(false);
			this.formGroup.get('gameBoardRows')!.disable();
			this.formGroup.get('gameBoardColumns')!.disable();
			this.formGroup.get('calcUrl')!.enable();
			this.formGroup.get('infiniteLevels')!.enable();
			this.formGroup.get('infiniteLevels')!.setValue(true);
			this.formGroup.get('minSelected')!.enable();
			this.formGroup.get('minValue')!.enable();
			this.formGroup.get('maxValue')!.enable();
		} else {
			this.formGroup.get('elementSize')!.enable();
			this.formGroup.get('imageMode')!.enable();
			this.formGroup.get('gameBoardRows')!.enable();
			this.formGroup.get('gameBoardColumns')!.enable();
			this.formGroup.get('calcUrl')!.disable();
			this.formGroup.get('minSelected')!.disable();
			this.formGroup.get('minSelected')!.setValue(0);
			this.formGroup.get('minValue')!.disable();
			this.formGroup.get('minValue')!.setValue(0);
			this.formGroup.get('maxValue')!.disable();
			this.formGroup.get('maxValue')!.setValue(100);
			this.formGroup.get('infiniteLevels')!.disable();
			this.formGroup.get('infiniteLevels')!.setValue(false);
		}
	}

	formatLabel(value: number | undefined) {
		return value + '%';
	}
}
