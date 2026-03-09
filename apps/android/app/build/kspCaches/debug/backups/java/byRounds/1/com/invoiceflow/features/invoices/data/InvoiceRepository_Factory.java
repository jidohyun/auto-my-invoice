package com.invoiceflow.features.invoices.data;

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
public final class InvoiceRepository_Factory implements Factory<InvoiceRepository> {
  private final Provider<ApiService> apiServiceProvider;

  public InvoiceRepository_Factory(Provider<ApiService> apiServiceProvider) {
    this.apiServiceProvider = apiServiceProvider;
  }

  @Override
  public InvoiceRepository get() {
    return newInstance(apiServiceProvider.get());
  }

  public static InvoiceRepository_Factory create(Provider<ApiService> apiServiceProvider) {
    return new InvoiceRepository_Factory(apiServiceProvider);
  }

  public static InvoiceRepository newInstance(ApiService apiService) {
    return new InvoiceRepository(apiService);
  }
}
