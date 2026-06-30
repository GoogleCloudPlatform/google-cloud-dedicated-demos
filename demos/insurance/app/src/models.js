/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import pkg from 'sequelize';
const { Model } = pkg;

export class RiskAnalysis extends Model {
  static init(sequelize, DataTypes) {
    return super.init(
      {
        analysis_id: {
          type: DataTypes.STRING,
          allowNull: false,
          primaryKey: true,
        },
        claim_id: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        is_documentation_complete: {
          type: DataTypes.BOOLEAN,
          defaultValue: true,
        },
        is_provider_flagged: {
          type: DataTypes.BOOLEAN,
          defaultValue: false,
        },
        is_amount_unusual: {
          type: DataTypes.BOOLEAN,
          defaultValue: false,
        },
        is_service_unusual: {
          type: DataTypes.BOOLEAN,
          defaultValue: false,
        },
      },
      {
        sequelize,
        modelName: "RiskAnalysis",
        tableName: "risk_analysis",
        timestamps: false,
      },
    );
  }
}

export class Claim extends Model {
  static init(sequelize, DataTypes) {
    const modal = super.init(
      {
        claim_id: {
          type: DataTypes.STRING,
          allowNull: false,
          primaryKey: true,
        },
        customer_id: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        provider_id: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        amount_billed: {
          type: DataTypes.DECIMAL,
          allowNull: false,
        },
        status: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        date_of_service: {
          type: DataTypes.DATE,
          allowNull: false,
        },
        public_insurance_base: {
          type: DataTypes.DECIMAL,
          allowNull: false,
        },
        mutuelle_coverage: {
          type: DataTypes.DECIMAL,
          allowNull: false,
        },
        processed_at: {
          type: DataTypes.DATE,
          allowNull: false,
        },
      },
      {
        sequelize,
        modelName: "Claim",
        tableName: "claims",
        timestamps: true,
        createdAt: "created_at",
        updatedAt: "updated_at",
      },
    );

    Claim.hasOne(RiskAnalysis, {
      foreignKey: "claim_id",
    });
    RiskAnalysis.belongsTo(Claim, {
      foreignKey: "claim_id",
    });

    return modal;
  }
}

export class Provider extends Model {
  static init(sequelize, DataTypes) {
    const model = super.init(
      {
        provider_id: {
          type: DataTypes.STRING,
          allowNull: false,
          primaryKey: true,
        },
        provider_name: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        provider_type: {
          type: DataTypes.STRING,
          allowNull: false,
        },
      },
      {
        sequelize,
        modelName: "Provider",
        tableName: "providers",
        timestamps: true,
        createdAt: "created_at",
        updatedAt: "updated_at",
      },
    );

    Provider.hasMany(Claim, {
      foreignKey: "provider_id",
    });
    Claim.belongsTo(Provider, {
      foreignKey: "provider_id",
    });

    return model;
  }
}

export class ServiceType extends Model {
  static init(sequelize, DataTypes) {
    const model = super.init(
      {
        service_type_id: {
          type: DataTypes.STRING,
          allowNull: false,
          primaryKey: true,
        },
        service_name: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        service_category: {
          type: DataTypes.STRING,
          allowNull: false,
        },
      },
      {
        sequelize,
        modelName: "ServiceType",
        tableName: "service_types",
        timestamps: true,
        createdAt: "created_at",
        updatedAt: "updated_at",
      },
    );

    ServiceType.hasMany(Claim, {
      foreignKey: "service_type_id",
    });
    Claim.belongsTo(ServiceType, {
      foreignKey: "service_type_id",
    });

    return model;
  }
}

export class Customer extends Model {
  static init(sequelize, DataTypes) {
    const model = super.init(
      {
        customer_id: {
          type: DataTypes.STRING,
          allowNull: false,
          primaryKey: true,
        },
        first_name: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        last_name: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        date_of_birth: {
          type: DataTypes.DATE,
          allowNull: false,
        },
      },
      {
        sequelize,
        modelName: "Customer",
        tableName: "customers",
        timestamps: true,
        createdAt: "created_at",
        updatedAt: "updated_at",
      },
    );

    Customer.hasMany(Claim, {
      foreignKey: "customer_id",
    });
    Claim.belongsTo(Customer, {
      foreignKey: "customer_id",
    });

    return model;
  }
}

export class InsurancePlan extends Model {
  static init(sequelize, DataTypes) {
    const model = super.init(
      {
        plan_id: {
          type: DataTypes.STRING,
          allowNull: false,
          primaryKey: true,
        },
        plan_name: {
          type: DataTypes.STRING,
          allowNull: false,
        },
      },
      {
        sequelize,
        modelName: "InsurancePlan",
        tableName: "insurance_plans",
        timestamps: true,
        createdAt: "created_at",
        updatedAt: "updated_at",
      },
    );

    InsurancePlan.hasMany(Claim, {
      foreignKey: "plan_id",
    });
    Claim.belongsTo(InsurancePlan, {
      foreignKey: "plan_id",
    });

    return model;
  }
}

export const models = [RiskAnalysis, Claim, Provider, ServiceType, Customer];
