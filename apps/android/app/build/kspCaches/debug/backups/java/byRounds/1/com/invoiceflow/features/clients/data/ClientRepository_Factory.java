package com.invoiceflow.features.clients.data;

import com.invoiceflow.core.network.ApiService;
import dagger.internal.DaggerGenerated;
import dagger.internal.Factory;
import dagger.internal.QualifierMetadata;
import dagger.internal.ScopeMetadata;
import javax.annotation.processing.Generated;
import javax.inject.Provider;

@ScopeMetadata("javax.inject.Singleton")
@QualifierMetadata
@DaggerGenerated
@Generated(
    value = "dagger.internal.codegen.ComponentProcessor",
    comments = "https://dagger.dev"
)
@SuppressWarnings({
    "unchecked",
    "rawtypes",
    "KotlinInternal",
    "KotlinInternalInJava",
    "cast",
    "deprecation"
})
public final class ClientRepository_Factory implements Factory<ClientRepository> {
  private final Provider<ApiService> apiServiceProvider;

  public ClientRepository_Factory(Provider<ApiService> apiServiceProvider) {
    this.apiServiceProvider = apiServiceProvider;
  }

  @Override
  public ClientRepository get() {
    return newInstance(apiServiceProvider.get());
  }

  public static ClientRepository_Factory create(Provider<ApiService> apiServiceProvider) {
    return new ClientRepository_Factory(apiServiceProvider);
  }

  public static ClientRepository newInstance(ApiService apiService) {
    return new ClientRepository(apiService);
  }
}
