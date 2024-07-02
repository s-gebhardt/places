import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({
	providedIn: 'root'
})
export class ApiService {

	constructor(private client: HttpClient) { }

	getRequest(url: string) {
		return this.client.get(url);
	}

	postRequest(url: string, body: any) {
		return this.client.post(url, body);
	}
}
