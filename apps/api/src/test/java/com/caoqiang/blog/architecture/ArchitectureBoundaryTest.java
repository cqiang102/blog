package com.caoqiang.blog.architecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

class ArchitectureBoundaryTest {

    private static final String[] BUSINESS_MODULES = {
            "admin", "ai", "audit", "auth", "content", "friend", "interaction", "user"
    };

    private static JavaClasses applicationClasses;

    @BeforeAll
    static void importApplicationClasses() {
        applicationClasses = new ClassFileImporter()
                .withImportOption(new ImportOption.DoNotIncludeTests())
                .importPackages("com.caoqiang.blog");
    }

    @Test
    void sharedKernelMustNotDependOnBusinessModules() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.shared..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.admin..",
                        "com.caoqiang.blog.ai..",
                        "com.caoqiang.blog.audit..",
                        "com.caoqiang.blog.auth..",
                        "com.caoqiang.blog.content..",
                        "com.caoqiang.blog.friend..",
                        "com.caoqiang.blog.interaction..",
                        "com.caoqiang.blog.user.."
                )
                .because("shared is a technical kernel and must not coordinate business modules")
                .check(applicationClasses);
    }

    @Test
    void domainMustNotDependOnApplicationOrInfrastructure() {
        noClasses()
                .that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "..application..",
                        "..infrastructure.."
                )
                .because("domain code must remain independent from orchestration and adapters")
                .check(applicationClasses);
    }

    @Test
    void applicationMustNotDependOnInfrastructure() {
        noClasses()
                .that().resideInAPackage("..application..")
                .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
                .because("adapter dependencies point toward application code, not the reverse")
                .check(applicationClasses);
    }

    @Test
    void businessModulesMustUsePublicApisOfOtherModules() {
        for (String consumer : BUSINESS_MODULES) {
            for (String provider : BUSINESS_MODULES) {
                if (consumer.equals(provider)) {
                    continue;
                }
                noClasses()
                        .that().resideInAPackage("com.caoqiang.blog." + consumer + "..")
                        .should().dependOnClassesThat().resideInAnyPackage(
                                "com.caoqiang.blog." + provider + ".domain..",
                                "com.caoqiang.blog." + provider + ".application.service..",
                                "com.caoqiang.blog." + provider + ".application.dto..",
                                "com.caoqiang.blog." + provider + ".infrastructure.."
                        )
                        .because(consumer + " must consume " + provider
                                + " through application/api, public events, or an explicit reverse port")
                        .check(applicationClasses);
            }
        }
    }

    @Test
    void eventListenersMustBeOwnedByBusinessModules() {
        classes()
                .that().haveSimpleNameEndingWith("EventListener")
                .should().resideOutsideOfPackage("com.caoqiang.blog.shared..")
                .because("event reactions belong to the consuming module")
                .check(applicationClasses);
    }

    @Test
    void userModuleMustNotDependOnAuthInternals() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.user..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.auth..")
                .because("auth may depend on the user model, but the user module uses an application port")
                .check(applicationClasses);
    }

    @Test
    void authDomainMustNotDependOnUserDomain() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.auth.domain..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.user..")
                .because("auth persistence stores user IDs instead of cross-module JPA entities")
                .check(applicationClasses);
    }

    @Test
    void authModuleMustNotAccessUserRepository() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.auth..")
                .should().dependOnClassesThat().resideInAPackage(
                        "com.caoqiang.blog.user.domain.repository.."
                )
                .because("authentication accesses users through the public user application API")
                .check(applicationClasses);
    }

    @Test
    void authModuleMustNotDependOnUserDomainModel() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.auth..")
                .should().dependOnClassesThat().resideInAPackage(
                        "com.caoqiang.blog.user.domain.model.."
                )
                .because("authentication uses immutable user-module snapshots")
                .check(applicationClasses);
    }

    @Test
    void interactionDomainMustStoreExternalAggregateIdsOnly() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.interaction.domain..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.content..",
                        "com.caoqiang.blog.user.."
                )
                .because("interaction entities store contentId and userId instead of cross-module entities")
                .check(applicationClasses);
    }

    @Test
    void interactionModuleMustUsePublicContentAndUserApis() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.interaction..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.content.domain..",
                        "com.caoqiang.blog.user.domain.."
                )
                .because("interaction workflows use public module snapshots and services")
                .check(applicationClasses);
    }

    @Test
    void aiChatDomainMustStoreUserIdsOnly() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.ai.chat.domain..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.user..")
                .because("AI chat sessions and quotas store scalar user IDs")
                .check(applicationClasses);
    }

    @Test
    void aiChatModuleMustUseThePublicUserApi() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.ai.chat..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.user.domain..")
                .because("AI chat resolves users through immutable user-module snapshots")
                .check(applicationClasses);
    }

    @Test
    void auditModuleMustStoreActorIdsAndUseThePublicUserApi() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.audit..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.user.domain..")
                .because("audit records store actorUserId and hydrate public user snapshots")
                .check(applicationClasses);
    }

    @Test
    void contentModuleMustNotCoordinateAiKnowledgeInternals() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.content..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.ai..")
                .because("content publishes lifecycle events and AI owns indexing reactions")
                .check(applicationClasses);
    }

    @Test
    void aiKnowledgeMustUseThePublicContentApi() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.ai.knowledge..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.content.domain..",
                        "com.caoqiang.blog.content.application.service..",
                        "com.caoqiang.blog.content.application.dto.."
                )
                .because("knowledge workflows consume content snapshots through application/api")
                .check(applicationClasses);
    }

    @Test
    void adminModuleMustNotAccessBusinessDomainRepositories() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.admin..")
                .should().dependOnClassesThat().resideInAPackage("..domain.repository..")
                .because("the dashboard composes module-owned overview APIs")
                .check(applicationClasses);
    }

    @Test
    void contentModuleMustUseThePublicInteractionApi() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.content..")
                .should().dependOnClassesThat().resideInAPackage("com.caoqiang.blog.interaction.domain..")
                .because("content reads like state through interaction/application/api")
                .check(applicationClasses);
    }

    @Test
    void aiChatToolsMustUsePublicContentAndInteractionApis() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.ai.chat..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.content.domain..",
                        "com.caoqiang.blog.content.application.service..",
                        "com.caoqiang.blog.content.application.dto..",
                        "com.caoqiang.blog.interaction.domain..",
                        "com.caoqiang.blog.interaction.application.service..",
                        "com.caoqiang.blog.interaction.application.dto.."
                )
                .because("AI tools consume module capabilities through application/api")
                .check(applicationClasses);
    }

    @Test
    void mediaConsumersMustUseThePublicContentApi() {
        noClasses()
                .that().resideInAnyPackage(
                        "com.caoqiang.blog.auth..",
                        "com.caoqiang.blog.friend..",
                        "com.caoqiang.blog.user.."
                )
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.content.domain..",
                        "com.caoqiang.blog.content.application.service..",
                        "com.caoqiang.blog.content.application.dto.."
                )
                .because("media consumers call content/application/api")
                .check(applicationClasses);
    }

    @Test
    void userWebMustUseThePublicInteractionApi() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.user..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.interaction.domain..",
                        "com.caoqiang.blog.interaction.application.service..",
                        "com.caoqiang.blog.interaction.application.dto.."
                )
                .because("the user activity surface consumes interaction/application/api")
                .check(applicationClasses);
    }

    @Test
    void adminModuleMustUseThePublicAuditApi() {
        noClasses()
                .that().resideInAPackage("com.caoqiang.blog.admin..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "com.caoqiang.blog.audit.domain..",
                        "com.caoqiang.blog.audit.application.service..",
                        "com.caoqiang.blog.audit.application.dto.."
                )
                .because("administration consumes audit/application/api")
                .check(applicationClasses);
    }
}
