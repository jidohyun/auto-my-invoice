package com.invoiceflow.features.invoices.viewmodel;

import com.invoiceflow.features.invoices.data.InvoiceRepository;
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
public final class InvoiceViewModel_Factory implements Factory<InvoiceViewModel> {
  private final Provider<InvoiceRepository> invoiceRepositoryProvider;

  public InvoiceViewModel_Factory(Provider<InvoiceRepository> invoiceRepositoryProvider) {
    this.invoiceRepositoryProvider = invoiceRepositoryProvider;
  }

  @Override
  public InvoiceViewModel get() {
    return newInstance(invoiceRepositoryProvider.get());
  }

  public static InvoiceViewModel_Factory create(
      Provider<InvoiceRepository> invoiceRepositoryProvider) {
    return new InvoiceViewModel_Factory(invoiceRepositoryProvider);
  }

  public static InvoiceViewModel newInstance(InvoiceRepository invoiceRepository) {
    return new InvoiceViewModel(invoiceRepository);
  }
}
