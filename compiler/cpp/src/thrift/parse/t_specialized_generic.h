/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#ifndef T_GENERIC_STRUCT_H
#define T_GENERIC_STRUCT_H

/*
#include <algorithm>
#include <vector>
#include <utility>
#include <string>

#include "thrift/parse/t_type.h"
#include "thrift/parse/t_field.h"

// Forward declare that puppy
class t_program;
*/

/**
 * A (partially or fully) specialized generic type
 */
class t_specialized_generic : public t_type {
public:
  t_specialized_generic(t_struct* declaration, std::vector<t_type*>* instantiation)
    : t_type(declaration->get_program(), declaration->get_name()),
      generic_declaration_(declaration),
      final_type_(nullptr),
      partially_specialized_(nullptr),
      tmpl_inst_type_(instantiation) {}

  t_specialized_generic(t_specialized_generic* partial, std::vector<t_type*>* instantiation)
    : t_type(partial->get_program(), partial->get_name()),
      generic_declaration_(nullptr),
      final_type_(nullptr),
      partially_specialized_(partial),
      tmpl_inst_type_(instantiation) {}

  virtual bool is_specialized_generic() const { return true; }

  // we can be a lot actually
  /* this is not safe due to hard casts being made so we better avoid it
  virtual bool is_struct() const { return get_underlying_type()->is_struct(); }
  virtual bool is_xception() const { return get_underlying_type()->is_xception(); }
  */

  /*
  mapped_type get_generic_type(std::map<std::string, mapped_type>* generic = nullptr);
  const mapped_type get_generic_type(std::map<std::string, mapped_type>* generic = nullptr) const;
  */

  const std::string get_symbolic() const {
    std::string fullsym(get_name());

    if (tmpl_inst_type_->size() > 0) {
      std::vector<t_type*>::const_iterator iter;
      std::string separator("<");
      for (iter = tmpl_inst_type_->begin(); tmpl_inst_type_->end() != iter; ++iter) {
        fullsym += separator;
        fullsym += (*iter)->get_name();
        separator = ",";      
      }
      fullsym += ">";
    }

    return fullsym;
  }

  virtual std::map<std::string, mapped_type>* map_template_types() {
    // already cached?
    if (tmpl_mapped_generic_types_.size() > 0) {
      return &tmpl_mapped_generic_types_;
    }

    // ensure all preconditions are in place
    const std::vector<std::string>* decls = get_template_decl_type();
    validate_template_instantiation(decls);

    // map generic types
    std::vector<t_type*>* instance = get_template_instance_type();
    if (decls->size() != tmpl_mapped_generic_types_.size()) {
      int expected_count = 0;
      std::vector<std::string>::const_iterator itKey = decls->begin();
      std::vector<t_type*>::const_iterator itVal = instance->begin();
      while ((decls->end() != itKey) && (instance->end() != itVal)) {
        tmpl_mapped_generic_types_[*itKey] = mapped_type(*itKey, *itVal);
        if (++expected_count != tmpl_mapped_generic_types_.size()) {
          printf("Duplicate type parameter %s at %s\n", itKey->c_str(), name_.c_str());
          exit(1);
        }
        ++itKey;
        ++itVal;
      }
    }

    return &tmpl_mapped_generic_types_;
  }

  t_type* construct_final_type() {
    // already cached?
    if (final_type_ != nullptr) {
      return final_type_;
    }

    auto* generic = get_underlying_type();
    auto* mapped = map_template_types();

    if (generic->is_struct() || generic->is_xception()) {
      auto* tstruct = (t_struct*)generic;
      final_type_ = new t_struct(*tstruct);
      final_type_->apply_template_specialization(mapped);
    } else {
      throw "construct_final_type: unhandled generic type";
    }
    return final_type_;
  }

  bool is_generic_instance() const {
    return (tmpl_inst_type_ != nullptr) && (tmpl_inst_type_->size() > 0);
  }

  virtual std::vector<t_type*>* get_template_instance_type() const {
    return tmpl_inst_type_;
  }

  virtual std::vector<std::string>* get_template_decl_type() const {
    return get_underlying_type()->get_template_decl_type();
  }

  virtual const t_type* get_true_type(std::map<std::string, mapped_type>* generic) const {
    auto* self = const_cast<t_specialized_generic*>(this);
    return self->construct_final_type();
  }


private:
  t_struct* generic_declaration_;  // original generic type decl (maybe null)
  t_specialized_generic* partially_specialized_;  // partial specialisation this one is based upon (maybe null)
  std::vector<t_type*>* tmpl_inst_type_;  // types applied during specialization 
  std::map<std::string, mapped_type> tmpl_mapped_generic_types_; // cached mapping
  t_type* final_type_; // constructed type = generic + specialisation

  t_type* get_underlying_type() const {
    if (partially_specialized_ != nullptr) {
      return partially_specialized_;
    }
    if (generic_declaration_ != nullptr) {
      return generic_declaration_;
    }
    printf("Unexpected state at generic type %s\n", name_.c_str());
    exit(1);
  }

  void validate_template_instantiation(const std::vector<std::string>* decls) const {
    std::vector<t_type*>* instance = get_template_instance_type();

    // either one null?
    if ((decls == nullptr) || (instance == nullptr)) {
      if (decls != nullptr) {
        printf("Missing type parameter for generic type %s\n", name_.c_str());
        exit(1);
      }
      if (instance != nullptr) {
        printf("Type %s is not generic and expects no type parameters\n", name_.c_str());
        exit(1);
      }
      return; // both null is ok
    }

    // same number of type parameters expected
    if (decls->size() != instance->size()) {
      printf("Generic type %s expects %d type parameters, but %d were specified\n", name_.c_str(),
             decls->size(), instance->size());
      exit(1);
    }
  }

};

#endif
