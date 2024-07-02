import { Directive, ElementRef } from '@angular/core';

@Directive({
	selector: '[troButton]',

})
export class ButtonDirective {

	constructor(private el: ElementRef) {
		this.el.nativeElement.classList.add('button');
	}

}
