package com.invoiceflow.features.clients.viewmodel;

import com.invoiceflow.features.clients.data.ClientRepository;
import dagger.internal.DaggerGenerated;
import dagger.internal.Factory;
import dagger.internal.QualifierMetadata;
import dagger.internal.ScopeMetadata;
import javax.annotation.processing.Generated;
import javax.inject.Provider;

@ScopeMetadata
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
public final class ClientViewModel_Factory implements Factory<ClientViewModel> {
  private final Provider<ClientRepository> clientRepositoryProvider;

  public ClientViewModel_Factory(Provider<ClientRepository> clientRepositoryProvider) {
    this.clientRepositoryProvider = clientRepositoryProvider;
  }

  @Override
  public ClientViewModel get() {
    return newInstance(clientRepositoryProvider.get());
  }

  public static ClientViewModel_Factory create(
      Provider<ClientRepository> clientRepositoryProvider) {
    return new ClientViewModel_Factory(clientRepositoryProvider);
  }

  public static ClientViewModel newInstance(ClientRepository clientRepository) {
    return new ClientViewModel(clientRepository);
  }
}
