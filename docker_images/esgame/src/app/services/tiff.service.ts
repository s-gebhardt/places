import { Injectable } from '@angular/core';
import { fromBlob, fromUrl } from 'geotiff';
import { Observable, from, mergeMap, of } from 'rxjs';
import gradients, { CustomColors, DefaultGradients, Gradient } from '../shared/helpers/gradients';
import { GameBoard } from '../shared/models/game-board';
import { GameBoardType } from '../shared/models/game-board-type';
import { Legend } from '../shared/models/legend';
import { FieldType } from '../shared/models/field-type';
import { Field } from '../shared/models/field';
import tiffToSvgPaths from '../shared/helpers/svg/tiffToSvgPaths';

@Injectable({
	providedIn: 'root'
})
export class TiffService {

	getGridGameBoard(id: string, url: string, defaultGradient: DefaultGradients, gameBoardType: GameBoardType) {
		return this.getTiffData(url).pipe(
			mergeMap(data => {
				let uniqueValues: number[], gradient: Gradient | undefined, legend: Legend, fields: Field[];

				uniqueValues = Array.from(new Set(data)).sort((a, b) => a - b);
				gradient = gradients.get(defaultGradient)!;
				legend = { elements: [...uniqueValues.map((o, i) => ({ forValue: o, color: gradient!.colors[i] }))], isNegative: gameBoardType == GameBoardType.ConsequenceMap, isGradient: false };

				fields = data.map((o, i) => {
					return new Field(i, new FieldType(gradient!.colors[(uniqueValues.indexOf(o))] as string, "CONFIGURED"), o);
				});
				const gameBoard = new GameBoard(id, gameBoardType, fields, legend);

				return of(gameBoard);
			})
		);
	}

	getSvgGameBoard(id: string, url: string, gameBoardType: GameBoardType, defaultGradient: DefaultGradients, overlay: GameBoard, minValue: number, maxValue: number) {
		return this.getTiffSvgDataUrl(url, minValue, maxValue, gradients.get(defaultGradient)!).pipe(
			mergeMap(data => {
				let gradient: Gradient | undefined, legend: Legend, fields: Field[];
        gradient = gradients.get(defaultGradient!);
				legend = { elements: [{ forValue: minValue, color: gradient!.calculateColor(1) }, { forValue: maxValue, color: gradient!.calculateColor(0) }], isNegative: gameBoardType == GameBoardType.ConsequenceMap, isGradient: true };
				fields = overlay.fields.map((field) => {
					return {
						...field,
						score: Math.round(data.numRaster[field.startPos]),
					}
				});

				const gameBoard = new GameBoard(id, gameBoardType, fields, legend, true, data.width, data.height, data.dataUrl);

				return of(gameBoard);
			})
		);
	}

	getOverlayGameBoard(id: string, url: string, gameBoardType: GameBoardType) {
		return this.getTiffSvgData(url).pipe(
			mergeMap(data => {
				let fields: Field[];

				fields = data.pathArray.map(path => {
					return new Field(path.id, new FieldType("", "CONFIGURED"), 0, null, path.id != data.nodata!, undefined, path.path, path.startPos);
				});

				return of(new GameBoard(id, gameBoardType, fields, undefined, true, data.width, data.height));
			})
		);
	}

	getSvgBackground(url: string, minValue: number, maxValue: number, customColors: CustomColors): Observable<string> {
		return this.getTiffSvgDataUrl(url, minValue, maxValue, undefined, customColors).pipe(
			mergeMap(data => {
				return of(data.dataUrl);
			})
		);
	}

	public getTiffData(url: string) {
		return from(this.tiffToArray(url));
	}

	public getTiffSvgDataUrl(url: string, minValue: number, maxValue: number, gradient?: Gradient, colors?: CustomColors) {
		return from(this.prepareDataUrl(url, minValue, maxValue, gradient, colors));
	}

	public getTiffSvgData(url: string) {
		return from(this.tiffToPaths(url));
	}

	private async prepareDataUrl(url: string, minValue: number, maxValue: number, gradient?: Gradient, colors?: CustomColors) {
		//fromURL throws error
		const tmp = await fetch(url).then(r => r.blob());
		const tiff = await fromBlob(tmp);
		const image = await tiff.getImage();
		const raster = await image.readRasters({ interleave: true });
		const numRaster = Array.from(raster.map(c => c as number));
		const width = image.getWidth();
		const height = image.getHeight();
		const nodata = image.getGDALNoData()!;

		const dataUrl = await this.arrayToImage(numRaster, width, nodata, minValue, maxValue, gradient, colors);
		return { width, height, dataUrl, nodata, numRaster };
	}

	private async tiffToPaths(url: string) {
		const tiff = await fromUrl(url);
		const image = await tiff.getImage();
		const raster = await image.readRasters({ interleave: true });
		const numRaster = Array.from(raster.map(c => Number.parseFloat(c.toString())));
		const paths = tiffToSvgPaths(numRaster, { width: image.getWidth(), height: undefined, scale: 1 });
		let pathArray: { id: number, path: string, startPos: number }[] = [];
		paths.forEach((val, key) => {
			pathArray.push({
				id: key,
				path: val,
				startPos: numRaster.indexOf(key)
			});
		});
		return { width: image.getWidth(), height: image.getHeight(), pathArray, nodata: image.getGDALNoData() };
	}

	private async tiffToArray(url: string): Promise<number[]> {
		const tiff = await fromUrl(url);
		const image = await tiff.getImage();
		const raster = await image.readRasters({ interleave: true });
		return Array.from(raster.map(c => Number.parseFloat(c.toString())));
	}

	private async arrayToImage(data: number[], columns: number, noData: number, minValue: number, maxValue: number, gradient?: Gradient, colors?: CustomColors): Promise<string> {
		const height = data.length / columns;
		const tmpArray: number[] = [];
		if (gradient) {
			data.forEach(value => {
				if (value == noData) {
					tmpArray.push(255, 255, 255, 0);
				} else {
					tmpArray.push(...gradient.calculateColorRGB(1 - 1 / (maxValue - minValue) * (value - minValue)), 255);
				}
			});
		} else if (colors) {
			data.forEach(value => {
				tmpArray.push(...colors!.getRgb(value)!);
			});
		}
		return this.arrayToDataUrl(tmpArray, columns, height);
	}

	// Source: https://stackoverflow.com/questions/22823752/creating-image-from-array-in-javascript-and-html5
	private arrayToDataUrl(data: number[], width: number, height: number) {
		let canvas = document.createElement('canvas'),
			ctx = canvas.getContext('2d')!;
		canvas.width = width;
		canvas.height = height;
		let image_data = ctx.createImageData(width, height);
		image_data.data.set(data);
		ctx.putImageData(image_data, 0, 0);
		return canvas.toDataURL();
	}
}


