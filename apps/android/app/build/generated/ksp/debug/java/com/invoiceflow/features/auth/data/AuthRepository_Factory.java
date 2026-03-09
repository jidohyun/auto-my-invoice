package com.invoiceflow.features.auth.data;

import com.invoiceflow.core.data.TokenRepository;
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
public final class AuthRepository_Factory implements Factory<AuthRepository> {
  private final Provider<ApiService> apiServiceProvider;

  private final Provider<TokenRepository> tokenRepositoryProvider;

  public AuthRepository_Factory(Provider<ApiService> apiServiceProvider,
      Provider<TokenRepository> tokenRepositoryProvider) {
    this.apiServiceProvider = apiServiceProvider;
    this.tokenRepositoryProvider = tokenRepositoryProvider;
  }

  @Override
  public AuthRepository get() {
    return newInstance(apiServiceProvider.get(), tokenRepositoryProvider.get());
  }

  public static AuthRepository_Factory create(Provider<ApiService> apiServiceProvider,
      Provider<TokenRepository> tokenRepositoryProvider) {
    return new AuthRepository_Factory(apiServiceProvider, tokenRepositoryProvider);
  }

  public static AuthRepository newInstance(ApiService apiService, TokenRepository tokenRepository) {
    return new AuthRepository(apiService, tokenRepository);
  }
}
