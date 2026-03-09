package com.invoiceflow.core.network;

import com.invoiceflow.core.data.TokenRepository;
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
public final class AuthInterceptor_Factory implements Factory<AuthInterceptor> {
  private final Provider<TokenRepository> tokenRepositoryProvider;

  public AuthInterceptor_Factory(Provider<TokenRepository> tokenRepositoryProvider) {
    this.tokenRepositoryProvider = tokenRepositoryProvider;
  }

  @Override
  public AuthInterceptor get() {
    return newInstance(tokenRepositoryProvider.get());
  }

  public static AuthInterceptor_Factory create(Provider<TokenRepository> tokenRepositoryProvider) {
    return new AuthInterceptor_Factory(tokenRepositoryProvider);
  }

  public static AuthInterceptor newInstance(TokenRepository tokenRepository) {
    return new AuthInterceptor(tokenRepository);
  }
}
