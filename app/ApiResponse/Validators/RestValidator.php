<?php

namespace App\ApiResponse\Validators;

use Illuminate\Support\MessageBag;
use Illuminate\Support\Str;
use Illuminate\Validation\Validator;

/**
 * Class RestValidator
 */
class RestValidator extends Validator
{

    /**
     * Add an error message to the validator's collection of messages.
     *
     * @param  string $attribute
     * @param  string $rule
     * @param  array $parameters
     *
     * @return void
     */
    protected function addError($attribute, $rule, $parameters)
    {
        $message = $this->getMessage($attribute, $rule);

        $message = $this->makeReplacements($message, $attribute, $rule, $parameters);

        $customMessage = new MessageBag();

        $customMessage->merge(['code' => strtolower($rule . '_rule_error')]);
        $customMessage->merge(['message' => $message]);

        $this->messages->add($attribute, $customMessage);
    }

    /**
     * Get the validation message for an attribute and rule.
     *
     * @param  string $attribute
     * @param  string $rule
     *
     * @return string
     */
    protected function getMessage($attribute, $rule)
    {
        $lowerRule = Str::snake($rule);

        $inlineMessage = $this->getInlineMessage($attribute, $lowerRule);

        // First we will retrieve the custom message for the validation rule if one
        // exists. If a custom validation message is being used we'll return the
        // custom message, otherwise we'll keep searching for a valid message.
        if (!is_null($inlineMessage)) {
            return $inlineMessage;
        }

        $customKey = "validation.custom.{$attribute}.{$lowerRule}";

        $customMessage = $this->getCustomMessageFromTranslator($customKey);

        // First we check for a custom defined validation message for the attribute
        // and rule. This allows the developer to specify specific messages for
        // only some attributes and rules that need to get specially formed.
        if ($customMessage !== $customKey) {
            return $customMessage;
        } elseif (in_array($rule, $this->sizeRules)) {
            // If the rule being validated is a "size" rule, we will need to gather the
            // specific error message for the type of attribute being validated such
            // as a number, file or string which all have different message types.
            return $this->getSizeMessage($attribute, $rule);
        }

        // Finally, if no developer specified messages have been set, and no other
        // special messages apply for this rule, we will just pull the default
        // messages out of the translator service for this validation rule.
        $key = "validation.{$lowerRule}";

        return $this->getInlineMessage($attribute, $lowerRule, $this->fallbackMessages) ?: $key;
    }

    /**
     * Get the proper error message for an attribute and size rule.
     *
     * @param  string $attribute
     * @param  string $rule
     *
     * @return string
     */
    protected function getSizeMessage($attribute, $rule)
    {
        $lowerRule = Str::snake($rule);

        // There are three different types of size validations. The attribute may be
        // either a number, file, or string so we will check a few things to know
        // which type of value it is and return the correct line for that type.
        $type = $this->getAttributeType($attribute);

        return "validation.{$lowerRule}.{$type}";
    }
}
