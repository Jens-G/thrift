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
 * A struct is a container for a set of member fields that has a name. Structs
 * are also used to implement exception types.
 *
 */
class t_generic_struct : public t_struct {
public:
  t_generic_struct(t_struct* declaration, const std::string& name, std::vector<t_type*>* instantiation)
    : t_struct(declaration->get_program(), declaration->get_name()), 
	  tmpl_inst_type_(instantiation)  {}

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

  bool is_generic_instance() const {
    return (tmpl_inst_type_ != nullptr) && (tmpl_inst_type_->size() > 0);
  }

  virtual std::vector<t_type*>* get_template_instance_type() const { return tmpl_inst_type_; }

private:
  std::vector<t_type*>* tmpl_inst_type_;
  std::map<std::string, mapped_type> tmpl_mapped_generic_types_;

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
