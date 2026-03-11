package com.invoiceflow.features.clients.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.clients.data.model.ClientRequest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ClientRepository @Inject constructor(private val apiService: ApiService) {

    suspend fun getClients(page: Int = 1, limit: Int = 20, query: String? = null) =
        apiService.getClients(page, limit, query)

    suspend fun getClient(id: String): ClientDto = apiService.getClient(id).data

    suspend fun createClient(request: ClientRequest): ClientDto = apiService.createClient(request).data

    suspend fun updateClient(id: String, request: ClientRequest): ClientDto = apiService.updateClient(id, request).data

    suspend fun deleteClient(id: String) = apiService.deleteClient(id)
}
