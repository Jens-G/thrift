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

#ifndef T_TYPEDEF_H
#define T_TYPEDEF_H

#include <string>
#include "thrift/parse/t_type.h"

/**
 * A typedef is a mapping from a symbolic name to another type. In dymanically
 * typed languages (i.e. php/python) the code generator can actually usually
 * ignore typedefs and just use the underlying type directly, though in C++
 * the symbolic naming can be quite useful for code clarity.
 *
 */
class t_typedef : public t_type {
public:
  t_typedef(t_program* program, t_type* type, const std::string& symbolic)
    : t_type(program, symbolic),
      type_(type),
      tmpl_inst_type_(nullptr),
      symbolic_(symbolic),
      forward_(false) {}

  /**
   * This constructor is used to refer to a type that is lazily
   * resolved at a later time, like for forward declarations or
   * recursive types.
   */
  t_typedef(t_program* program, const std::string& symbolic, bool forward)
    : t_type(program, symbolic),
      type_(nullptr),
      tmpl_inst_type_(nullptr),
      symbolic_(symbolic),
      forward_(forward) {}

  t_typedef(t_program* program, const std::string& symbolic, std::vector<t_type*>* tmpl_type)
    : t_type(program, symbolic),
      type_(nullptr),
      tmpl_inst_type_(tmpl_type),
      symbolic_(symbolic),
      forward_(true) {}

  ~t_typedef() override = default;

  t_type* get_type(std::map<std::string, mapped_type>* generic = nullptr);

  //const t_type* get_type(std::map<std::string, mapped_type>* generic = nullptr) const;

  mapped_type get_generic_type(std::map<std::string, mapped_type>* generic = nullptr);

  const mapped_type get_generic_type(std::map<std::string, mapped_type>* generic = nullptr) const;

  const std::string get_symbolic() const {
    std::string fullsym(symbolic_);

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

  bool is_generic_instance() const {
    return (tmpl_inst_type_ != nullptr) && (tmpl_inst_type_->size() > 0);
  }

  bool is_forward_typedef() const { return forward_; }

  bool is_typedef() const override { return true; }

  virtual std::vector<t_type*>* get_template_instance_type() const { return tmpl_inst_type_; }

  virtual std::map<std::string, mapped_type>* map_template_types() {
    // already cached?
    if (tmpl_mapped_generic_types_.size() > 0) {
      return &tmpl_mapped_generic_types_;
    }

    // ensure all preconditions are in place
    const t_type* ttype = get_type(nullptr);
    const std::vector<std::string>* decls = ttype->get_template_decl_type();
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

private:
  t_type* type_;
  std::string symbolic_;
  bool forward_;
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
